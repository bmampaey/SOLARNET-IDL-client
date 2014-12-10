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


FUNCTION get_datasets, _EXTRA = filters
	url_scheme = 'http'
	url_host = 'benjmam-pc:8000'
	url_path = 'api/v1/dataset?limit=0'
	schema_url_path = 'api/v1/dataset/schema'
	url = OBJ_NEW('IDLnetUrl', URL_SCHEME=url_scheme, URL_HOST=url_host)
	
	IF N_ELEMENTS(filters) NE 0 THEN BEGIN
		
		url->SetProperty, /VERBOSE, URL_PATH=schema_url_path
		data_raw = url->Get( /STRING_ARRAY )
		data = JSON_PARSE(data_raw, /TOSTRUCT)
		fields = data.fields
		
		filter_names = TAG_NAMES(filters)
		FOR i = 0, N_ELEMENTS(filter_names) - 1 DO BEGIN
			url_path = url_path + expand_filter(fields, filter_names[i], filters.(i))
		ENDFOR
	ENDIF
	
	PRINT, "Getting ", url_path
	
	url->SetProperty, /VERBOSE, URL_PATH=url_path
	data_raw = url->Get( /STRING_ARRAY )
	data = JSON_PARSE(data_raw, /TOSTRUCT)
	RETURN, data.objects
END

FUNCTION get_meta_datas, dataset, offset = offset, limit = limit, _EXTRA = filters
	url_scheme = 'http'
	url_host = 'benjmam-pc:8000'
	url_path = 'api/v1/' + dataset.name + '_meta_data?'
	schema_url_path = 'api/v1/' + dataset.name + '_meta_data/schema'
	url = OBJ_NEW('IDLnetUrl', URL_SCHEME=url_scheme, URL_HOST=url_host)
	
	IF N_ELEMENTS(offset) EQ 0 THEN offset = 0
	IF N_ELEMENTS(limit) EQ 0 THEN limit = 0
	
	url_path = url_path + "limit=" + STRTRIM(limit,2) + "&offset=" + STRTRIM(offset,2)
	
	offset = offset + limit
	
	IF N_ELEMENTS(filters) NE 0 THEN BEGIN
		url->SetProperty, /VERBOSE, URL_PATH=schema_url_path
		data_raw = url->Get( /STRING_ARRAY )
		data = JSON_PARSE(data_raw, /TOSTRUCT)
		fields = data.fields
		
		filter_names = TAG_NAMES(filters)
		FOR i = 0, N_ELEMENTS(filter_names) - 1 DO BEGIN
			url_path = url_path + expand_filter(fields, filter_names[i], filters.(i))
		ENDFOR
	ENDIF
	
	PRINT, "Getting ", url_path
	
	url->SetProperty, /VERBOSE, URL_PATH=url_path
	data_raw = url->Get( /STRING_ARRAY )
	data = JSON_PARSE(data_raw, /TOSTRUCT)
	RETURN, data.objects
END

FUNCTION download_data, meta_data, dir = dir
	
	IF N_ELEMENTS(dir) EQ 0 THEN dir = '.'
	
	path = strsplit(meta_data.data_location.url, '/', /EXTRACT)
	filename = dir + PATH_SEP() + path[N_ELEMENTS(path) - 1]
	
	url = OBJ_NEW('IDLnetUrl')
	RETURN, url->Get(FILENAME=filename, URL=meta_data.data_location.url)
END
