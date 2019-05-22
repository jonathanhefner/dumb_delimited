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
    with_various_options do
      [nil, false, true].each do |eol|
        line = Row.new(*values).to_s(*eol)

        assert_equal (COLUMNS.length - 1), line.scan(Row.delimiter).length
        values.each do |value|
          assert_includes line, value
        end
        assert_equal !!eol, line.end_with?($INPUT_RECORD_SEPARATOR)
      end
    end
  end

  def test_parse_line
    row = Row.new(*make_values("foo"))
    with_various_options do
      assert_equal row, Row.parse_line(to_csv([row]))
    end
  end

  def test_parse
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_various_options do
      assert_equal rows, Row.parse(to_csv(rows))
      assert_equal rows, Row.parse(StringIO.new(to_csv(rows)))
    end
  end

  def test_parse_text_aliases_parse
    assert_equal :parse, Row.method(:parse_text).original_name
  end

  def test_parse_each_with_block
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_various_options do
      [String, StringIO].each do |data_class|
        each_rows = []
        Row.parse_each(data_class.new(to_csv(rows))) do |row|
          each_rows << row
        end

        assert_equal rows, each_rows
      end
    end
  end

  def test_parse_each_without_block
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_various_options do
      [String, StringIO].each do |data_class|
        enum = Row.parse_each(data_class.new(to_csv(rows)))

        assert enum.is_a?(Enumerable)
        assert_equal rows, enum.to_a
      end
    end
  end

  def test_read
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_tmp_file do |path|
      with_various_options do
        File.write(path, to_csv(rows))

        assert_equal rows, Row.read(path)
      end
    end
  end

  def test_parse_file_aliases_read
    assert_equal :read, Row.method(:parse_file).original_name
  end

  def test_read_each_with_block
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_tmp_file do |path|
      with_various_options do
        File.write(path, to_csv(rows))
        each_rows = []
        Row.read_each(path) do |row|
          each_rows << row
        end

        assert_equal rows, each_rows
      end
    end
  end

  def test_read_each_without_block
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_tmp_file do |path|
      with_various_options do
        File.write(path, to_csv(rows))
        enum = Row.read_each(path)

        assert enum.is_a?(Enumerable)
        assert_equal rows, enum.to_a
      end
    end
  end

  def test_write
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_tmp_file do |path|
      with_various_options do
        Row.write(path, rows)

        assert_equal to_csv(rows), File.read(path)
      end
    end
  end

  def test_write_with_append
    rows = (1..3).map{|id| Row.new(*make_values(id)) }
    with_tmp_file do |path|
      with_various_options do
        Row.write(path, rows, append: true)

        assert_equal to_csv(rows), File.read(path)

        Row.write(path, rows, append: true)

        assert_equal to_csv(rows + rows), File.read(path)
      ensure
        File.delete(path)
      end
    end
  end

  def test_append_to_file
    Dir.mktmpdir do |dir|
      all_at_once = dir.to_pathname + "all_at_once"
      one_by_one = dir.to_pathname + "one_by_one"

      rows = (1..3).map{|id| Row.new(*make_values(id)) }
      with_various_options do
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

  def with_various_options(&block)
    block.call

    Row.delimiter = "\t"
    block.call

    Row.delimiter = "!@#$%"
    block.call

    Row.options[:headers] = COLUMNS
    block.call

    Row.options[:headers] = true
    Row.options[:write_headers] = true
    block.call
  end

  def to_csv(rows)
    CSV.generate(Row.options) do |csv|
      if Row.options[:write_headers] && !Row.options[:headers].is_a?(Array)
        csv << COLUMNS
      end

      rows.each do |row|
        csv << row.to_a
      end
    end
  end

  def with_tmp_file(&block)
    Dir.mktmpdir do |dir|
      block.call(File.join(dir, "file"))
    end
  end

end
