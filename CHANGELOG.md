## 2.0.0

* [BREAKING] Do not activate `options[:converters]` by default
* [BREAKING] Remove *pleasant_path* dependency.  This is considered a
  breaking change because *pleasant_path* adds extension methods to
  several Ruby core classes that consumer code may depend on.
* [BREAKING] Remove `append_to_file` instance method
* [BREAKING] Rename `each_in_file` class method to `read_each`
* Add `parse_each` class method
* Rename `parse_file` class method to `read`, and alias as `parse_file`
* Rename `parse_text` class method to `parse`, and alias as `parse_text`
* Add `write` class method
* Add `append` class method
* Add `eol` parameter to `to_s` instance method
* Add `DumbDelimited.csv`, `.psv`, and `.tsv` convenience shortcuts
* Activate `options[:liberal_parsing]` by default
* Make `options` inheritable
* Fix behavior when `options[:headers]` is set
* Fix behavior when `options[:write_headers]` is set


## 1.1.0

* Add `parse_text` class method
* Add `append_to_file` instance method
* Fix gem load on case-sensitive file systems


## 1.0.0

* Initial release
