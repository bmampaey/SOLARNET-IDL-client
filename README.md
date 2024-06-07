SOLARNET Virtual Observatory (SVO)
==================================
The SVO is a service first supported by the [SOLARNET](http://solarnet-east.eu/) project, funded by the European Commission’s FP7 Capacities Programme under the Grant Agreement 312495. Then made operational thanks to the [SOLARNET2](https://solarnet-project.eu) project, funded by the the European Union's Horizon 2020 Research and Innovation Programme under Grant Agreement 824135.

It's purpose is to collect metadata from as many solar observations as possible, especially those made thanks to the SOLARNET projects, in a common catalog and make them available to the scientific community.

A first prototype version was released in February 2016, and the operational version is available now at https://solarnet2.oma.be

The SVO code is split in several parts:
- A [web server](https://github.com/bmampaey/SOLARNET-server)
- A [web client](https://github.com/bmampaey/SOLARNET-web-client)
- A [python client](https://github.com/bmampaey/SOLARNET-python-client)
- An [IDL client](https://github.com/bmampaey/SOLARNET-IDL-client)
- [Data provider tools](https://github.com/bmampaey/SOLARNET-provider-tools)

SOLARNET API IDL client
==========================

This package can be used as a client or as an example how to work with the API using IDL version 8.2 or higher. It requires the [IDLAstro library](https://asd.gsfc.nasa.gov/archive/idlastro/) to be installed and accessible via the [IDL_PATH variable](https://www.nv5geospatialsoftware.com/docs/prefs_directory.html) 

Example usage
-------------

```IDL
.compile SOLARNET

; See all available datasets
datasets = get_datasets()
FOR i = 0, N_ELEMENTS(datasets) - 1 DO HELP, datasets[i]

; Get a specific dataset
datasets = get_datasets(name = 'Swap Level 1')
swap_dataset = datasets[0]

; Get some metadatas from the swap dataset
metadatas = get_metadatas(swap_dataset)
HELP, metadatas[0]

; Download the data corresponding to the metadata
PRINT, download_data(metadatas[0], dir = '/tmp')

; Metadata can be filtered using the keywords of the dataset
; E.g. get the metadatas from the swap dataset starting the 1st January 2011
metadatas = get_metadatas(swap_dataset, date_obs={min: '2011-01-01'})
FOR i = 0, N_ELEMENTS(metadatas) - 1 DO PRINT, metadatas[i].date_obs

; If more than 1 filter is specified, they will all be applied
; E.g. get the metadatas from the swap dataset for the month of January 2011 AND with an exposure time < 10 seconds
metadatas = get_metadatas(swap_dataset, date_obs={min: '2011-01-01', max: '2011-02-01'}, exptime={max: 10})
FOR i = 0, N_ELEMENTS(metadatas) - 1 DO PRINT, metadatas[i].date_obs, metadatas[i].exptime

; Some datasets have millions of records, so by default the number of metadatas returned is limited to 20, and the maximum is 100.
; If you want to process a lot of metadatas, you can use the limit and the offset keywords as such to request it by batch
offset = 0
limit = 10
REPEAT BEGIN $
   metadatas = get_metadatas(swap_dataset, date_obs={min: '2011-01-01', max: '2011-02-01'}, OFFSET = offset, LIMIT = limit) & $
   PRINT, 'OFFSET', offset & $ ; At each call to get_metadatas, offset will be increased
   ; Do some processing with the metadatas
ENDREP UNTIL N_ELEMENTS(metadatas) LT limit

```

Filters
-------

To filter the datasets or the metadatas, depending on the type of the field, you can pass the following types of parameters:

### Numeric filter
 - To specify an exact value, pass the value as such: `field_name = value`. Be carefull, filtering like this on float/double may not have the expected effect.
 - To specify a range [min_value, max_value[, pass a struct as such: `field_name = {min: min_value, max: max_value}`. You can specify only the min or the max. The min value is inclusive, the max value is exclusive.

### String filter
Filtering on string is case insensitive.

 - To specify an exact value, pass the value as such: `field_name = value`
 - To specify a string that *starts with* a value, pass a struct as such: `field_name = {startswith: value}`
 - To specify a string that *contains* a value, pass a struct as such: `field_name = {contains: value}`
 - To specify a string that *ends with* a value, pass a struct as such: `field_name = {endswith: value}`

The last three can be combined together into a single struct. For example `get_datasets(instrument={startswith: 'proba', endswith: '2'})` will retrun the datasets for the instruments starting with 'proba' **AND** ending with '2', thus 'proba2' but not 'proba3', nor 'eit2'

### Time filter
To specify a time range, pass a struct as such `field_name = {min: first_date, max: last_date}`. You can specify only the min or the max. The min value is inclusive, the max value is exclusive. *first_date* and *last_date* must respect the ISO format, i.e. "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SSZ".
 
