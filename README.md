# DTA_Reader Class

This is a simple class for Ruby that allows to read iTNC 530 oscilloscope data and export it as a
TSV file.

## Interface

#### `DTA_reader.new(inputfile, outputfile = nil)`

The class initializer reuires a string as input that represents the path to the `.dta` file. 
An output file string may be specified to export directly the file.

The initializer also runs the `parse` private method, that collect all data starting from trigger point.

#### `DTA_reader.export(outputfile)`

Exports data as TSV in a file specified by argument string variable.

#### `DTA_reader.fileinfo`

Hash that contains some information about the file.

``` ruby
DTA_reader.fileinfo = {
  :sampling => Fixnum # sampling time in nS
  :count    => Fixnum # number of collected elements
  :trigger  => Fixnum # Trigger index value 
}
```

#### `DTA_reader.output_ary`

Array that contains channels value data. Each channel is an Hash that has the following structure:

``` ruby
DTA_reader.output_ary[0] = {
  :id     => Fixnum # channel id. 0 for Time channel, automatically generated
  :name   => String # A name (without spaces) to identify the collected values
  :unit   => String # Measurement unit of the channel
  :values => Array  # Array of collected values, scaled using factor from raw data
  :factor => Float  # Scaling factor for raw data
  :offset => Fixnum # Line at wich data are written in original file
}
```

  
