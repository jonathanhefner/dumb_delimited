require "csv"
require_relative "dumb_delimited/version"


module DumbDelimited

  # Returns a model class for delimited data consisting of the specified
  # +columns+.  The returned class inherits from Ruby's
  # {https://docs.ruby-lang.org/en/trunk/Struct.html +Struct+}, allowing
  # data manipulation via accessor methods, via indexing by column name,
  # and via indexing by column number.  See {ClassMethods} and
  # {InstanceMethods} for the additional methods the returned class
  # provides.
  #
  # @example
  #   class Product < DumbDelimited[:sku, :name, :base_price, :sale_price]
  #     def on_sale?
  #       sale_price.to_f < base_price.to_f
  #     end
  #   end
  #
  # @example
  #   Customer = DumbDelimited[:name, :email, :address]
  #
  # @param columns [Array<Symbol>]
  # @return [Class<Struct>]
  def self.[](*columns)
    Struct.new(*columns) do
      extend DumbDelimited::ClassMethods
      include DumbDelimited::InstanceMethods
    end
  end

  # Convenience shortcut to create a model class and set
  # {ClassMethods#delimiter} to +","+.
  #
  # Note: This method exists mostly for parity with {psv} and {tsv}.
  # Unless +CSV::DEFAULT_OPTIONS+ has been modified, the delimiter will
  # already default to +","+.
  #
  # @example
  #   # This...
  #   Point = DumbDelimited.csv(:x, :y, :z)
  #
  #   # ...is equivalent to:
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.delimiter = ","
  #
  # @param columns [Array<Symbol>]
  # @return [Class<Struct>]
  def self.csv(*columns)
    klass = self[*columns]
    klass.delimiter = ","
    klass
  end

  # Convenience shortcut to create a model class and set
  # {ClassMethods#delimiter} to +"|"+.
  #
  # @example
  #   # This...
  #   Point = DumbDelimited.psv(:x, :y, :z)
  #
  #   # ...is equivalent to:
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.delimiter = "|"
  #
  # @param columns [Array<Symbol>]
  # @return [Class<Struct>]
  def self.psv(*columns)
    klass = self[*columns]
    klass.delimiter = "|"
    klass
  end

  # Convenience shortcut to create a model class and set
  # {ClassMethods#delimiter} to <code>"\t"</code>.
  #
  # @example
  #   # This...
  #   Point = DumbDelimited.tsv(:x, :y, :z)
  #
  #   # ...is equivalent to:
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.delimiter = "\t"
  #
  # @param columns [Array<Symbol>]
  # @return [Class<Struct>]
  def self.tsv(*columns)
    klass = self[*columns]
    klass.delimiter = "\t"
    klass
  end

end


module DumbDelimited::ClassMethods

  # Returns the CSV options Hash.  The Hash is not +dup+ed and can be
  # modified directly.  Any modifications will be applied to all future
  # IO operations for the model class.
  #
  # For detailed information about available options, see Ruby's
  # {https://docs.ruby-lang.org/en/trunk/CSV.html#method-c-new CSV
  # class}.
  #
  # @return [Hash<Symbol, Object>]
  def options
    @options ||= if superclass == Struct
      CSV::DEFAULT_OPTIONS.merge(
        skip_blanks: true,
        liberal_parsing: true,
      )
    else
      superclass.options.dup
    end
  end

  # Sets the CSV options Hash.  The entire Hash is replaced, and the new
  # values will be applied to all future IO operations for the model
  # class.  To set options individually, see {options}.
  #
  # For detailed information about available options, see Ruby's
  # {https://docs.ruby-lang.org/en/trunk/CSV.html#method-c-new CSV
  # class}.
  #
  # @param opts [Hash<Symbol, Object>]
  # @return [Hash<Symbol, Object>]
  def options=(opts)
    @options = opts
  end

  # Returns the column delimiter used in IO operations.  Defaults to a
  # comma (<code>","</code>).
  #
  # Equivalent to <code>options[:col_sep]</code>.
  #
  # @return [String]
  def delimiter
    self.options[:col_sep]
  end

  # Sets the column delimiter used in IO operations.  The new value will
  # be used in all future IO operations for the model class.  Any
  # delimiter can be safely chosen, and all IO operations will quote
  # field values as necessary.
  #
  # Equivalent to <code>options[:col_sep] = delim</code>.
  #
  # @example
  #   Point = DumbDelimited[:x, :y, :z]
  #   p = Point.new(1, 2, 3)
  #   p.to_s  # == "1,2,3"
  #   Point.delimiter = "|"
  #   p.to_s  # == "1|2|3"
  #
  # @param delim [String]
  # @return [String]
  def delimiter=(delim)
    self.options[:col_sep] = delim
  end

  # Parses a single delimited line into a model object.
  #
  # @example
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.parse_line("1,2,3")  # == Point.new(1, 2, 3)
  #
  # @param line [String]
  # @return [Struct]
  def parse_line(line)
    parse_each(line).first
  end

  # Parses a string or IO object into an array of model objects.
  #
  # @example
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.parse("1,2,3\n4,5,6\n7,8,9\n")
  #     # == [
  #     #      Point.new(1, 2, 3),
  #     #      Point.new(4, 5, 6),
  #     #      Point.new(7, 8, 9)
  #     #    ]
  #
  # @param data [String, IO]
  # @return [Array<Struct>]
  def parse(data)
    parse_each(data).to_a
  end

  alias_method :parse_text, :parse

  # Parses a string or IO object one line at a time, yielding a model
  # object for each line.
  #
  # An Enumerator is returned if no block is given.
  #
  # @overload parse_each(data, &block)
  #   @param data [String, IO]
  #   @yieldparam model [Struct]
  #   @return [void]
  #
  # @overload parse_each(data)
  #   @param data [String, IO]
  #   @return [Enumerator<Struct>]
  def parse_each(data, &block)
    return to_enum(__method__, data) unless block_given?

    csv_each(CSV.new(data, self.options), &block)
  end

  # Parses a file into an array of model objects.  This will load the
  # entire contents of the file into memory, and may not be suitable for
  # large files.  To iterate over file contents without loading it all
  # into memory at once, use {read_each}.
  #
  # @example
  #   # CONTENTS OF FILE "points.csv":
  #   # 1,2,3
  #   # 4,5,6
  #   # 7,8,9
  #
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.read("points.csv")
  #     # == [
  #     #      Point.new(1, 2, 3),
  #     #      Point.new(4, 5, 6),
  #     #      Point.new(7, 8, 9)
  #     #    ]
  #
  # @param path [String, Pathname]
  # @return [Array<Struct>]
  def read(path)
    read_each(path).to_a
  end

  alias_method :parse_file, :read

  # Parses a file one line at a time, yielding a model object for each
  # line.  This avoids loading the entire contents of the file into
  # memory at once.
  #
  # An Enumerator is returned if no block is given.  Note that some
  # Enumerator methods, such as +Enumerator#to_a+, can cause the entire
  # contents of the file to be loaded into memory.
  #
  # @overload read_each(path, &block)
  #   @param path [String, Pathname]
  #   @yieldparam model [Struct]
  #   @return [void]
  #
  # @overload read_each(path)
  #   @param path [String, Pathname]
  #   @return [Enumerator<Struct>]
  def read_each(path, &block)
    return to_enum(__method__, path) unless block_given?

    CSV.open(path, self.options) do |csv|
      csv_each(csv, &block)
    end
  end

  # Writes a collection of model objects to a file in delimited format.
  # The previous contents of the file are overwritten, unless +append+
  # is set to true.
  #
  # Column headers are written to the file if +:write_headers+ in
  # {options} is set to true *and* either +append+ is false or the file
  # is empty / non-existent.  The column headers will be derived from
  # either the value of +:headers+ in {options} if it is an Array, or
  # otherwise from the columns defined by the model.
  #
  # @param path [String, Pathname]
  # @param models [Enumerable<Struct>]
  # @param append [Boolean]
  # @return [void]
  def write(path, models, append: false)
    mode = append ? "a" : "w"
    write_headers = options[:write_headers] && !(append && File.exist?(path) && File.size(path) > 0)
    headers = (!options[:headers].is_a?(Array) && write_headers) ? members : options[:headers]

    CSV.open(path, mode, **options, write_headers: write_headers, headers: headers) do |csv|
      models.each{|model| csv << model }
    end
  end

  # Appends a collection of model objects to a file in delimited format.
  # Convenience shortcut for {write} with +append: true+.
  #
  # @param path [String, Pathname]
  # @param models [Enumerable<Struct>]
  # @return [void]
  def append(path, models)
    write(path, models, append: true)
  end

  private

  def csv_each(csv, &block)
    csv.each do |row|
      row = row.fields if row.is_a?(CSV::Row)
      block.call(self.new(*row))
    end
  end

end


module DumbDelimited::InstanceMethods

  # Serializes a model object to a delimited string, using the delimiter
  # specified by {ClassMethods#delimiter}.  By default, the string will
  # not end with a line terminator.  To end the string with a line
  # terminator designated by +:row_sep+ in {ClassMethods#options}, set
  # +eol+ to true.
  #
  # @param eol [Boolean]
  # @return [String]
  def to_s(eol = false)
    row_sep = eol ? self.class.options[:row_sep] : -""

    CSV.generate(**self.class.options, row_sep: row_sep, write_headers: false) do |csv|
      csv << self
    end
  end

end
