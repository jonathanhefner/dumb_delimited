# dumb_delimited

A library for unsophisticated delimited flat file IO.  *dumb_delimited*
mixes models and persistence in that "probably wrong but feels so right"
kind of way.


## Usage Example

Let's say we have a products file "products.csv", and a customers
file "customers.psv".

"products.csv" is a comma-delimited flat file and has four columns: SKU,
Product Name, Base Price, and Sale Price.  An example row from
"products.csv" might be:

```
AB81H0F,Widget Alpha,899.99,499.99
```

"customers.psv" is a pipe-delimited flat file and has three columns:
Customer Name, Email, and Address.  An example row from "customers.psv"
might be:

```
Bob Bobbington|best_bob@bobbers.bob|808 Bounce Lane, Austin, TX 78703
```

To interact with these files, we create model classes via the
`DumbDelimited::[]` method.  Note that a created class can either be
used as a superclass or simply assigned to a constant.

```ruby
class Product < DumbDelimited[:sku, :name, :base_price, :sale_price]
  def on_sale?
    sale_price < base_price
  end
end

Customer = DumbDelimited[:name, :email, :address]
Customer.delimiter = "|"
```

Because "customers.psv" is pipe-delimited, we also set the delimiter
for the Customer class.  By default, model classes use comma (`","`) as
the delimiter.  Whenever a delimiter is set, it applies to all future
IO operations for that model class.

Now we can read each flat file, and recieve an array of model objects.

```ruby
products = Product.read("products.csv")
customers = Customer.read("customers.psv")
```

However, this will load the entire contents of each file into memory.
Let's say our customers file is very large, and we would prefer to
iterate over it one row at a time rather than load it all into memory at
once.  To do so, we can use the `each_in_file` method.  Below is a
complete example in which we load our product data, create a listing of
products on sale, and iterate over our customers, notifying each
customer of the sale products:

```ruby
products = Product.read("products.csv")

listing = products.select(&:on_sale?).map do |product|
  "* #{product.name} (#{product.sale_price})"
end.join("\n")

Customer.each_in_file("customers.psv") do |customer|
  message = <<~MESSAGE
    Hi #{customer.name}!

    The following products are on sale:

    #{listing}
  MESSAGE

  notify(customer.email, message)
end
```

Let's say the sale is now over, and we want to change our sale prices
back to our base prices.  *dumb_delimited* includes the
[*pleasant_path*](https://rubygems.org/gems/pleasant_path) gem, which
offers a fluent API for writing files.  To finish our task, we use the
`Array#write_to_file` method provided by *pleasant_path*, which in turn
invokes `Product#to_s` (provided by *dumb_delimited*) on each model
object.

```ruby
Product.read("products.csv").each do |product|
  product.sale_price = product.base_price
end.write_to_file("products.csv")
```

For a more detailed explanation of the *dumb_delimited* API, browse the
[API documentation](http://www.rubydoc.info/gems/dumb_delimited/).


## Installation

Install from [Ruby Gems](https://rubygems.org/gems/dumb_delimited):

```bash
$ gem install dumb_delimited
```

Then require in your Ruby script:

```ruby
require "dumb_delimited"
```


## Contributing

Run `rake test` to run the tests.  You can also run `rake irb` for an
interactive prompt that pre-loads the project code.


## License

[MIT License](https://opensource.org/licenses/MIT)
