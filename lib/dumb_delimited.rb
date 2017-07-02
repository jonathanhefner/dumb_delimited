require "CSV"
require "pleasant_path"
require "dumb_delimited/version"


module DumbDelimited

  def self.[](*columns)
    Struct.new(*columns) do
      extend DumbDelimited::ClassMethods
      include DumbDelimited::InstanceMethods
    end
  end

end


module DumbDelimited::ClassMethods

  def options
    @options ||= {
      col_sep: ',',
      skip_blanks: true,
      converters: :numeric,
    }
  end

  def options=(o)
    @options = o
  end

  def delimiter
    self.options[:col_sep]
  end

  def delimiter=(d)
    self.options[:col_sep] = d
  end

  def parse_line(line)
    self.new(*CSV.parse_line(line, self.options))
  end

  def parse_file(path)
    each_in_file(path).to_a
  end

  def each_in_file(path)
    return to_enum(__method__, path) unless block_given?

    CSV.foreach(path, self.options) do |row|
      yield self.new(*row)
    end
  end

end


module DumbDelimited::InstanceMethods

  def to_s
    CSV.generate_line(self, self.class.options).chomp!
  end

end
