require "CSV"
require "pleasant_path"
require_relative "dumb_delimited/version"


module DumbDelimited

  # Returns a model class for delimited data consisting of the specified
  # columns.  The returned class inherits from Ruby's
  # {https://ruby-doc.org/core/Struct.html +Struct+}, allowing data
  # manipulation via accessor methods, via indexing by column name, and
  # via indexing by column number.  See {ClassMethods} and
  # {InstanceMethods} for the IO methods the returned class provides.
  #
  # @example
  #   class Product < DumbDelimited[:sku, :name, :base_price, :sale_price]
  #     def on_sale?
  #       sale_price < base_price
  #     end
  #   end
  #
  #   Customer = DumbDelimited[:name, :email, :address]
  #
  # @param columns [*Symbol]
  # @return [Class]
  def self.[](*columns)
    Struct.new(*columns) do
      extend DumbDelimited::ClassMethods
      include DumbDelimited::InstanceMethods
    end
  end

end


module DumbDelimited::ClassMethods

  # Returns the advanced options Hash.  The Hash is not +dup+ed and can
  # be modified directly.  Any modifications will be applied to all
  # future IO operations for the model class.  For detailed information
  # about available options, see Ruby's
  # {http://ruby-doc.org/stdlib/libdoc/csv/rdoc/CSV.html#method-c-new
  # CSV module}.
  #
  # @return [Hash]
  def options
    @options ||= {
      col_sep: ',',
      skip_blanks: true,
      converters: :numeric,
    }
  end

  # Sets the advanced options Hash.  The entire Hash is replaced, and
  # the new value will be applied to all future IO operations for the
  # model class.  To set options individually, see {options}.  For
  # detailed information about available options, see Ruby's
  # {http://ruby-doc.org/stdlib/libdoc/csv/rdoc/CSV.html#method-c-new
  # CSV module}.
  #
  # @param o [Hash]
  def options=(o)
    @options = o
  end

  # Returns the column delimiter used in IO operations.  Defaults to a
  # comma (<code>","</code>).
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
  # @example
  #   Point = DumbDelimited[:x, :y, :z]
  #   p = Point.new(1, 2, 3)
  #   p.to_s  # == "1,2,3"
  #   Point.delimiter = "|"
  #   p.to_s  # == "1|2|3"
  #
  # @param d [String]
  def delimiter=(d)
    self.options[:col_sep] = d
  end

  # Parses a single delimited line into a model object.
  #
  # @example
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.parse_line("1,2,3")  # == Point.new(1, 2, 3)
  #
  # @param line [String]
  # @return [self]
  def parse_line(line)
    self.new(*CSV.parse_line(line, self.options))
  end

  # Parses an entire delimited file into an array of model objects.
  # This will load the entire contents of the file into memory, and may
  # not be suitable for large files.  To iterate over file contents
  # without loading it all into memory at once, use {each_in_file}.
  #
  # @example
  #   # CONTENTS OF FILE "points.csv":
  #   # 1,2,3
  #   # 4,5,6
  #   # 7,8,9
  #
  #   Point = DumbDelimited[:x, :y, :z]
  #   Point.parse_file("points.csv")
  #     # == [
  #     #      Point.new(1, 2, 3),
  #     #      Point.new(4, 5, 6),
  #     #      Point.new(7, 8, 9)
  #     #    ]
  #
  # @param path [String, Pathname]
  # @return [Array<self>]
  def parse_file(path)
    each_in_file(path).to_a
  end

  # Iterates over a delimited file, parsing one row at a time into model
  # objects.  This avoids loading the entire contents of the file into
  # memory at once.  If a block is given, it will be passed a model
  # object for each row in the file.  Otherwise, if a block is not
  # given, an Enumerator will be returned.  Note that some Enumerator
  # methods, such as +Enumerator#to_a+, will cause the entire contents
  # of the file to be loaded into memory regardless.
  #
  # @param path [String, Pathname]
  # @yieldparam [self] current model object
  # @return [Enumerator<self>, nil]
  def each_in_file(path)
    return to_enum(__method__, path) unless block_given?

    CSV.foreach(path, self.options) do |row|
      yield self.new(*row)
    end
  end

end


module DumbDelimited::InstanceMethods

  # Serializes a model object to a delimited string, using the delimiter
  # specified by {ClassMethods.delimiter}.
  #
  # @return [String]
  def to_s
    CSV.generate_line(self, self.class.options).chomp!
  end

end
