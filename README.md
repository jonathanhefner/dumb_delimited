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
    sale_price.to_f < base_price.to_f
  end
end

Customer = DumbDelimited[:name, :email, :address]
Customer.delimiter = "|"
```

Because "customers.psv" is pipe-delimited, we also set the delimiter
for the Customer class.  By default, a model class uses a comma (`","`)
as its delimiter.  Whenever a delimiter is set, it applies to all future
IO operations for that model class.

Convenience shortcuts that create a model class and set its delimiter
are also provided for a few common delimiters.  Notably,
`DumbDelimited::psv` for a model class with a pipe (`"|"`) delimiter.
Thus, the `Customer` class could alternatively be written as:

```ruby
Customer = DumbDelimited.psv(:name, :email, :address)
```

Using our model classes, we can read each flat file, and recieve an
array of model objects:

```ruby
products = Product.read("products.csv")
customers = Customer.read("customers.psv")
```

However, this will load the entire contents of each file into memory.
Let's say our customers file is very large, and we would prefer to
iterate over it one row at a time rather than load it all into memory at
once.  To do so, we can use the `read_each` method.  Below is a complete
example in which we load our product data, create a listing of products
on sale, and iterate over our customers, notifying each customer of the
sale products:

```ruby
products = Product.read("products.csv")

listing = products.select(&:on_sale?).map do |product|
  "* #{product.name} (#{product.sale_price})"
end.join("\n")

Customer.read_each("customers.psv") do |customer|
  message = <<~MESSAGE
    Hi #{customer.name}!

    The following products are on sale:

    #{listing}
  MESSAGE

  notify(customer.email, message)
end
```

Let's say the sale is now over, and we want to change our sale prices
back to our base prices.  We can load our product data, modify it
directly, and finally persist it back with the `write` method:

```ruby
products = Product.read("products.csv")

products.each do |product|
  product.sale_price = product.base_price
end

Product.write("products.csv", products)
```

For a more detailed explanation of the *dumb_delimited* API, browse the
[API documentation](https://www.rubydoc.info/gems/dumb_delimited/).


## Installation

Install the [gem](https://rubygems.org/gems/dumb_delimited):

```bash
$ gem install dumb_delimited
```

Then require in your Ruby code:

```ruby
require "dumb_delimited"
```


## Contributing

Run `rake test` to run the tests.


## License

[MIT License](LICENSE.txt)
