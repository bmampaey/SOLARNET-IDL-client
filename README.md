SOLARNET API client
===================

Common usage
------------
```IDL
.compile SOLARNET

; See all available datasets
datasets = get_datasets()
FOR i = 0, N_ELEMENTS(datasets) - 1 DO HELP, datasets[i]

; Get a specific dataset
datasets = get_datasets(name = 'swap')
swap_dataset = datasets[0]

; Get meta-datas from the swap dataset
meta_datas = get_metadatas(swap_dataset, limit = 20)
HELP, meta_datas[0]

; It is important to pass a limit value if you suspect that get_metadatas will return a lot of information (some datasets have millions of entries)
; If you want to process a lot of meta_datas you can use the limit and the offset keywords as such
offset = 0
limit = 20
REPEAT BEGIN
   meta_datas = get_meta_datas(swap_dataset, OFFSET = offset, LIMIT = limit)
   PRINT, offset; at each call offset will be increased
   ; Do some processing with the meta-datas
ENDREP UNTIL N_ELEMENTS(meta_datas) LT limit


; Get some specific meta-datas from the swap dataset (all of it for the 1st January 2011)
meta_datas = get_meta_datas(swap_dataset, date_obs={min: '2011-01-01', max: '2011-01-02'})
FOR i = 0, N_ELEMENTS(meta_datas) - 1 DO PRINT, meta_datas[i].date_obs

; Download the data corresponding to some meta data
PRINT, download_data(meta_datas[0], dir = '/tmp')

```

Filters
-------

To filter the datasets or the meta-datas, depending on the type of the field, you can pass the following types of parameters:

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
To specify a time range, pass a struct as such `field_name = {min: first_date, max: last_date}`. You can specify only the min or the max. The min value is inclusive, the max value is exclusive. *first_date* and *last_date* must respect the ISO format, i.e. "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SS".
 