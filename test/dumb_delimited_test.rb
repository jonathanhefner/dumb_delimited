require "test_helper"

class DumbDelimitedTest < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil ::DumbDelimited::VERSION
  end

  def test_creation
    hash = make_hash
    row = make_row_from_hash(hash)

    assert_hash_and_row_match hash, row
  end

  def test_line_round_trip
    hash = make_hash
    row = make_row_from_hash(hash)

    line = row.to_s
    row_again = Row.parse_line(line)

    assert_hash_and_row_match hash, row_again
  end

  def test_file_round_trip
    make_hashes_then_write_to_file_then do |hashes, path|
      rows_again = Row.parse_file(path)

      assert_hashes_and_rows_match hashes, rows_again
    end
  end

  def test_file_iteration_with_block
    make_hashes_then_write_to_file_then do |hashes, path|
      rows_again = []
      Row.each_in_file(path) do |row|
        rows_again << row
      end

      assert_hashes_and_rows_match hashes, rows_again
    end
  end

  def test_file_iteration_without_block
    make_hashes_then_write_to_file_then do |hashes, path|
      enum = Row.each_in_file(path)
      assert enum.is_a?(Enumerable)

      rows_again = enum.to_a
      assert_hashes_and_rows_match hashes, rows_again
    end
  end

  def test_different_delimiter
    default_delimiter = Row.delimiter # save

    delimiter = '!ARBITRARY!'
    Row.delimiter = delimiter
    assert_equal delimiter, Row.delimiter

    hash = make_hash
    row = make_row_from_hash(hash)

    line = row.to_s
    row_again = Row.parse_line(line)

    assert_equal (COLUMNS.length - 1), line.scan(delimiter).length
    assert_hash_and_row_match hash, row_again

    Row.delimiter = default_delimiter # restore
  end


  private

  COLUMNS = [:a, :b, :c]

  Row = DumbDelimited[*COLUMNS]

  def make_hash(identifier = nil)
    COLUMNS.reduce({}) do |hash, col|
      hash.merge(col => "__#{col}__#{identifier}")
    end
  end

  def make_row_from_hash(hash)
    Row.new(*COLUMNS.map{|c| hash[c] })
  end

  def make_hashes_then_write_to_file_then(&block)
    Dir.mktmpdir do |dir|
      path = dir / 'file'
      hashes = 13.times.map{|i| make_hash(i) }
      rows = hashes.map{|h| make_row_from_hash(h) }
      rows.write_to_file(path)
      block.call(hashes, path)
    end
  end

  def assert_hash_and_row_match(hash, row)
    COLUMNS.each_with_index do |col, i|
      assert_equal hash[col], row[i], "Bad value in row at index #{i}"
      assert_equal hash[col], row[col], "Bad value in row at key #{col}"
      assert_equal hash[col], row.send(col), "Bad value in row from attribute #{col}"
    end
  end

  def assert_hashes_and_rows_match(hashes, rows)
    assert_equal hashes.length, rows.length, "Different number of hashes and rows"
    hashes.zip(rows).each do |h, r|
      assert_hash_and_row_match h, r
    end
  end

end
