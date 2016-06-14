FUNCTION string_filter, field_name, value
	filter = ''
	IF TYPENAME(value) EQ 'STRING' THEN BEGIN
		filter = filter + '&' + STRLOWCASE(field_name) + '__iexact=' + value
	ENDIF ELSE BEGIN
		IF TAG_EXIST(value, 'startswith', /TOP_LEVEL) THEN filter = filter + '&' + STRLOWCASE(field_name) + '__istartswith=' + value.startswith
		IF TAG_EXIST(value, 'endswith', /TOP_LEVEL) THEN filter = filter + '&' + STRLOWCASE(field_name) + '__iendswith=' + value.endswith
		IF TAG_EXIST(value, 'contains', /TOP_LEVEL) THEN filter = filter + '&' + STRLOWCASE(field_name) + '__icontains=' + value.contains
	ENDELSE
	RETURN, filter
END

FUNCTION numeric_filter, field_name, value
	filter = ''
	IF WHERE(['BYTE', 'INT', 'LONG', 'LONG64', 'FLOAT', 'DOUBLE'] EQ TYPENAME(value)) GE 0 THEN BEGIN
		filter = filter + '&' + STRLOWCASE(field_name) + '__exact=' + STRTRIM(value, 2)
	ENDIF ELSE BEGIN
		IF TAG_EXIST(value, 'min', /TOP_LEVEL) THEN filter = filter + '&' + STRLOWCASE(field_name) + '__gte=' + STRTRIM(value.min, 2)
		IF TAG_EXIST(value, 'max', /TOP_LEVEL) THEN filter = filter + '&' + STRLOWCASE(field_name) + '__lt=' + STRTRIM(value.max, 2)
	ENDELSE
	RETURN, filter
END

FUNCTION time_filter, field_name, value
	filter = ''
	IF TAG_EXIST(value, 'min', /TOP_LEVEL) THEN BEGIN
		TIMESTAMPTOVALUES, value.min, YEAR=year, MONTH=month, DAY=day, HOUR=hour, MINUTE=minute, SECOND=second, OFFSET=offset
		filter = filter + '&' + STRLOWCASE(field_name) + '__gte=' + value.min
	ENDIF
	IF TAG_EXIST(value, 'max', /TOP_LEVEL) THEN BEGIN
		TIMESTAMPTOVALUES, value.max, YEAR=year, MONTH=month, DAY=day, HOUR=hour, MINUTE=minute, SECOND=second, OFFSET=offset
		filter = filter + '&' + STRLOWCASE(field_name) + '__lt=' + value.max
	ENDIF
	RETURN, filter
END

FUNCTION related_filter, field_name, value
	IF TYPENAME(value) EQ 'STRING' THEN RETURN, '&' + STRLOWCASE(field_name) + '=' + value ELSE RETURN, '&' + STRLOWCASE(field_name) + '=' + STRTRIM(value, 2)
END

FUNCTION expand_filter, fields, filter_name, filter_value
	field_names = TAG_NAMES(fields)
	index = WHERE(STRCMP(field_names, filter_name, /FOLD_CASE) EQ 1)
	IF index LT 0 THEN BEGIN
		MESSAGE, 'Unknown field '+ filter_name
	ENDIF ELSE BEGIN
		field = fields.(index)
		CASE field.type OF 
			'string': RETURN, string_filter(filter_name, filter_value)
			'integer': RETURN, numeric_filter(filter_name, filter_value)
			'float': RETURN, numeric_filter(filter_name, filter_value)
			'datetime': RETURN, time_filter(filter_name, filter_value)
			'related': RETURN, related_filter(filter_name, filter_value)
			ELSE : MESSAGE, 'Filter for type ' + field.type + ' has not been implemented!'
		ENDCASE
	ENDELSE
END

;+
;	:Author:  Benjamin Mampaey
;	:Keywords:
;		verbose : In, Optional, Type=boolean
;		*field_name* : In, Optional
;			*field_name* is any tag of a meta_data struct. See https://github.com/bmampaey/SOLARNET-IDL-client for more information. 
;	:Return: A list of dataset struct
;	:Uses: IDLnetUrl, JSON_PARSE
;	:History: See https://github.com/bmampaey/SOLARNET-IDL-client/commits/master
;	:Examples:
;		datasets = get_datasets(); Get all the datasets
;		datasets = get_datasets(name= 'swap'); Get the dataset named swap
;		datasets = get_datasets(telescope= 'SDO'); Get the datasets from the SDO telescope
;-

FUNCTION get_datasets, VERBOSE=verbose, _EXTRA = filters
	; Check the version number as JSON_PARSE is only available from version 8.2
	version = STRSPLIT(!VERSION.RELEASE, '.', /EXTRACT)
	IF ~(FIX(version[0]) GE 8 && FIX(version[1]) GE 2) THEN MESSAGE, 'IDL version 8.2 or higher is required for this function!'
	
	url_scheme = 'http'
	url_host = 'solarnet.oma.be'
	url_path = 'SDA/api/v1/dataset?limit=0'
	schema_url_path = 'SDA/api/v1/dataset/schema'
	url = OBJ_NEW('IDLnetUrl', URL_SCHEME=url_scheme, URL_HOST=url_host, VERBOSE = verbose)
	
	IF N_ELEMENTS(filters) NE 0 THEN BEGIN
		
		url->SetProperty, URL_PATH=schema_url_path
		data_raw = url->Get( /STRING_ARRAY )
		data = JSON_PARSE(data_raw, /TOSTRUCT)
		fields = data.fields
		
		filter_names = TAG_NAMES(filters)
		FOR i = 0, N_ELEMENTS(filter_names) - 1 DO BEGIN
			url_path = url_path + expand_filter(fields, filter_names[i], filters.(i))
		ENDFOR
	ENDIF
	
	url->SetProperty, URL_PATH=url_path
	data_raw = url->Get( /STRING_ARRAY )
	data = JSON_PARSE(data_raw, /TOSTRUCT)
	RETURN, data.objects
END

;+
;	:Author:  Benjamin Mampaey
;	:Params: 
;		dataset : in, required, type=struct 
;			A dataset struct as returned by the get_datasets function 
;	:Keywords: 
;		limit : In, Optional, Default=20,  Type=int
;			The maximum number of records to return. Set to 0 to disable the limit (inadvisable if large number of records expected !)
;		offset : In/Out, Optional, Type=int
;			The starting index of records requested. Use in combination with limit to request a large set of records in smaller calls.  
;		verbose : In, Optional, Type=boolean
;		*field_name* : In, Optional
;			*field_name* is any tag of a meta_data struct. See https://github.com/bmampaey/SOLARNET-IDL-client for more information. 
;	:Return: A list of meta_data struct
;	:Uses: IDLnetUrl, JSON_PARSE
;	:History: See https://github.com/bmampaey/SOLARNET-IDL-client/commits/master
;	:Examples:
;		datasets = get_datasets(name= 'swap'); Get the swap dataset
;		swap_dataset = datasets[0]
;		meta_datas = get_meta_datas(swap_dataset); Get some meta-datas from the swap dataset
;		meta_datas = get_meta_datas(swap_dataset, date_obs={min: '2011-01-01', max: '2011-01-02'}, limit = 0); Get all the meta-datas from the swap dataset for the 1st January 2011
;		meta_datas = get_meta_datas(swap_dataset, date_obs={min: '2011-01-01', max: '2011-01-02'}, exptime = 10, limit = 0); Get all the meta-datas from the swap dataset for the 1st January 2011 and with a exposure time of exactly 10 seconds
;-

FUNCTION get_meta_datas, dataset, offset = offset, limit = limit, VERBOSE=verbose, _EXTRA = filters
	; Check the version number as JSON_PARSE is only available from version 8.2
	version = STRSPLIT(!VERSION.RELEASE, '.', /EXTRACT)
	IF ~(FIX(version[0]) GE 8 && FIX(version[1]) GE 2) THEN MESSAGE, 'IDL version 8.2 or higher is required for this function!'
	
	url_scheme = 'http'
	url_host = 'solarnet.oma.be'
	url_path = 'SDA/api/v1/metadata/' + dataset.id + '?'
	schema_url_path = 'SDA/api/v1/' + dataset.id + '/schema'
	url = OBJ_NEW('IDLnetUrl', URL_SCHEME=url_scheme, URL_HOST=url_host, VERBOSE = verbose)
	
	IF N_ELEMENTS(offset) EQ 0 THEN offset = 0
	IF N_ELEMENTS(limit) EQ 0 THEN limit = 20
	
	url_path = url_path + "limit=" + STRTRIM(limit,2) + "&offset=" + STRTRIM(offset,2)
	
	offset = offset + limit
	
	IF N_ELEMENTS(filters) NE 0 THEN BEGIN
		url->SetProperty, URL_PATH=schema_url_path
		data_raw = url->Get( /STRING_ARRAY )
		data = JSON_PARSE(data_raw, /TOSTRUCT)
		fields = data.fields
		
		filter_names = TAG_NAMES(filters)
		FOR i = 0, N_ELEMENTS(filter_names) - 1 DO BEGIN
			url_path = url_path + expand_filter(fields, filter_names[i], filters.(i))
		ENDFOR
	ENDIF
	
	
	url->SetProperty, URL_PATH=url_path
	data_raw = url->Get( /STRING_ARRAY )
	data = JSON_PARSE(data_raw, /TOSTRUCT)
	RETURN, data.objects
END


;+
;	:Author:  Benjamin Mampaey
;	:Params: 
;		meta_data : in, required, type=struct 
;			A meta_data struct as returned by the get_meta_datas function 
;	:Keywords: 
;		dir : In, Optional, Type=string
;			The directory where to download the file.
;		verbose : In, Optional, Type=boolean
;	:Return: The path to the downloaded file
;	:Uses: IDLnetUrl
;	:History: See https://github.com/bmampaey/SOLARNET-IDL-client/commits/master
;	:Examples:
;		PRINT, download_data(meta_datas[0], dir = '/tmp')
;-

FUNCTION download_data, meta_data, dir = dir, VERBOSE=verbose
	
	IF N_ELEMENTS(dir) EQ 0 THEN dir = '.'
	
	path = strsplit(meta_data.data_location.file_url, '/', /EXTRACT)
	filename = dir + PATH_SEP() + path[N_ELEMENTS(path) - 1]
	
	url = OBJ_NEW('IDLnetUrl', VERBOSE = verbose)
	RETURN, url->Get(FILENAME=filename, URL=meta_data.data_location.file_url)
END
