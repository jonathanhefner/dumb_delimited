require "test_helper"

class DumbDelimitedTest < Minitest::Test

  def setup
    @original_options = Row.options.dup
  end

  def teardown
    Row.options = @original_options
  end

  def test_that_it_has_a_version_number
    refute_nil ::DumbDelimited::VERSION
  end

  def test_inherits_from_struct
    assert_kind_of Struct, Row.new
  end

  def test_members
    assert_equal COLUMNS, Row.members
  end

  def test_initializer
    values = make_values("foo")
    row = Row.new(*values)

    assert_equal values, row.to_a
  end

  def test_options_attr
    expected = Row.options.merge(col_sep: "#{__method__}")
    Row.options = expected

    assert_equal expected, Row.options
  end

  def test_options_defaults
    assert_equal ",", Row.options[:col_sep]
    assert_equal true, Row.options[:skip_blanks]
    assert_equal true, Row.options[:liberal_parsing]
    assert_equal :numeric, Row.options[:converters]
  end

  def test_options_is_mutable
    Row.options[:col_sep] = "#{__method__}"

    assert_equal "#{__method__}", Row.options[:col_sep]
  end

  def test_options_mutations_are_isolated
    another_class = DumbDelimited[*COLUMNS]
    another_class.options[:col_sep] = "#{__method__}"

    refute_equal "#{__method__}", Row.options[:col_sep]
  end

  def test_options_are_inherited
    Row.options[:col_sep] = "#{__method__}"
    subclass = Class.new(Row)

    assert_equal "#{__method__}", subclass.options[:col_sep]
  end

  def test_options_mutations_in_subclass_are_isolated
    subclass = Class.new(Row)
    subclass.options[:col_sep] = "#{__method__}"

    refute_equal "#{__method__}", Row.options[:col_sep]
  end

  def test_options_cover_csv_default_options
    assert_equal CSV::DEFAULT_OPTIONS.keys, (CSV::DEFAULT_OPTIONS.keys & Row.options.keys)
  end

  def test_delimiter_attribute
    Row.delimiter = "#{__method__}"

    assert_equal "#{__method__}", Row.delimiter
    assert_equal "#{__method__}", Row.options[:col_sep]
  end

  def test_to_s
    values = make_values("foo")
    with_various_delimiters do
      line = Row.new(*values).to_s

      assert_equal (COLUMNS.length - 1), line.scan(Row.delimiter).length
      values.each do |value|
        assert_includes line, value
      end
    end
  end

  def test_parse_line
    row = Row.new(*make_values("foo"))
    with_various_delimiters do
      assert_equal row, Row.parse_line(row.to_s)
    end
  end

  def test_parse_text
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_various_delimiters do
      assert_equal rows, Row.parse_text(rows.join("\n"))
    end
  end

  def test_parse_file
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_various_delimiters do
      write_rows_then(rows) do |path|
        assert_equal rows, Row.parse_file(path)
      end
    end
  end

  def test_each_in_file_with_block
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_various_delimiters do
      write_rows_then(rows) do |path|
        each_rows = []
        Row.each_in_file(path) do |row|
          each_rows << row
        end

        assert_equal rows, each_rows
      end
    end
  end

  def test_each_in_file_without_block
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_various_delimiters do
      write_rows_then(rows) do |path|
        enum = Row.each_in_file(path)

        assert enum.is_a?(Enumerable)
        assert_equal rows, enum.to_a
      end
    end
  end

  def test_append_to_file
    Dir.mktmpdir do |dir|
      all_at_once = dir.to_pathname + "all_at_once"
      one_by_one = dir.to_pathname + "one_by_one"

      rows = (1..3).map{|id| Row.new(*make_values(id)) }
      with_various_delimiters do
        rows.write_to_file(all_at_once)
        rows.each{|row| row.append_to_file(one_by_one) }

        assert_equal File.read(all_at_once), File.read(one_by_one)
      ensure
        File.delete(one_by_one)
      end
    end
  end

  private

  COLUMNS = [:a, :b, :c]

  Row = DumbDelimited[*COLUMNS]

  def make_values(id)
    COLUMNS.map{|col| "row_#{id}_col_#{col}" }
  end

  def with_various_delimiters(&block)
    [nil, "\t", "!@#$%"].each do |delimiter|
      Row.delimiter = delimiter if delimiter
      block.call
    end
  end

  def write_rows_then(rows, &block)
    Dir.mktmpdir do |dir|
      path = dir.to_pathname + "file"
      rows.write_to_file(path)
      block.call(path)
    end
  end

end
