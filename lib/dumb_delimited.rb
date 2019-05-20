require "csv"
require "pleasant_path"
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
  #       sale_price < base_price
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
        converters: :numeric,
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
    self.new(*CSV.parse_line(line, self.options))
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
    # using CSV.new.each instead of CSV.parse to avoid unnecessary mass
    # memory allocation and deallocation
    CSV.new(data, self.options).each.map{|row| self.new(*row) }
  end

  alias_method :parse_text, :parse

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
  def read_each(path)
    return to_enum(__method__, path) unless block_given?

    CSV.foreach(path, self.options) do |row|
      yield self.new(*row)
    end
  end

end


module DumbDelimited::InstanceMethods

  # Serializes a model object to a delimited string, using the delimiter
  # specified by {ClassMethods#delimiter}.
  #
  # @return [String]
  def to_s
    CSV.generate_line(self, self.class.options).chomp!
  end

  # Serializes a model object to a delimited string, using the delimiter
  # specified by {ClassMethods#delimiter}, and appends the string plus a
  # row separator to the specified file.  Returns the model object.
  #
  # This method is convenient when working with single model objects.
  # For example, when appending a single entry to a log file.  However,
  # it is not recommended for use with an array of model objects due to
  # the overhead of opening and closing the file for each append.
  #
  # @example
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.new(1, 2, 3).append_to_file("out.txt")  # == Point.new(1, 2, 3)
  #   File.read("out.txt")                          # == "1,2,3\n"
  #   Point.new(4, 5, 6).append_to_file("out.txt")  # == Point.new(4, 5, 6)
  #   File.read("out.txt")                          # == "1,2,3\n4,5,6\n"
  #
  # @param file [String, Pathname]
  # @return [Struct]
  def append_to_file(file)
    CSV.generate_line(self, self.class.options).append_to_file(file)
    self
  end

end
