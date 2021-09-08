FUNCTION has_tag, struct, tag
	RETURN, WHERE(TAG_NAMES(struct) EQ STRUPCASE(tag)) GE 0
END

FUNCTION string_filter, field_name, value
	filter = ''
	IF TYPENAME(value) EQ 'STRING' THEN BEGIN
		filter = filter + '&' + STRLOWCASE(field_name) + '__iexact=' + value
	ENDIF ELSE BEGIN
		IF has_tag(value, 'startswith') THEN filter = filter + '&' + STRLOWCASE(field_name) + '__istartswith=' + value.startswith
		IF has_tag(value, 'endswith') THEN filter = filter + '&' + STRLOWCASE(field_name) + '__iendswith=' + value.endswith
		IF has_tag(value, 'contains') THEN filter = filter + '&' + STRLOWCASE(field_name) + '__icontains=' + value.contains
	ENDELSE
	RETURN, filter
END

FUNCTION numeric_filter, field_name, value
	filter = ''
	IF WHERE(['BYTE', 'INT', 'LONG', 'LONG64', 'FLOAT', 'DOUBLE'] EQ TYPENAME(value)) GE 0 THEN BEGIN
		filter = filter + '&' + STRLOWCASE(field_name) + '__exact=' + STRTRIM(value, 2)
	ENDIF ELSE BEGIN
		IF has_tag(value, 'min') THEN filter = filter + '&' + STRLOWCASE(field_name) + '__gte=' + STRTRIM(value.min, 2)
		IF has_tag(value, 'max') THEN filter = filter + '&' + STRLOWCASE(field_name) + '__lt=' + STRTRIM(value.max, 2)
	ENDELSE
	RETURN, filter
END

FUNCTION time_filter, field_name, value
	filter = ''
	IF has_tag(value, 'min') THEN BEGIN
		TIMESTAMPTOVALUES, value.min, YEAR=year, MONTH=month, DAY=day, HOUR=hour, MINUTE=minute, SECOND=second, OFFSET=offset
		filter = filter + '&' + STRLOWCASE(field_name) + '__gte=' + value.min
	ENDIF
	IF has_tag(value, 'max') THEN BEGIN
		TIMESTAMPTOVALUES, value.max, YEAR=year, MONTH=month, DAY=day, HOUR=hour, MINUTE=minute, SECOND=second, OFFSET=offset
		filter = filter + '&' + STRLOWCASE(field_name) + '__lt=' + value.max
	ENDIF
	RETURN, filter
END

FUNCTION related_filter, field_name, value
	IF TYPENAME(value) EQ 'STRING' THEN RETURN, '&' + STRLOWCASE(field_name) + '=' + value ELSE RETURN, '&' + STRLOWCASE(field_name) + '=' + STRTRIM(value, 2)
END

FUNCTION get_api_data, url_path, url_query, VERBOSE=verbose
	; Check the version number as JSON_PARSE is only available from version 8.2
	version = STRSPLIT(!VERSION.RELEASE, '.', /EXTRACT)
	IF ~(FIX(version[0]) GE 8 && FIX(version[1]) GE 2) THEN MESSAGE, 'IDL version 8.2 or higher is required for this function!'
	
	; The URL_PATH must not start with a slash, so strip it from the url_path
	IF url_path.CharAt(0) EQ '/' THEN url_path = STRMID(url_path, 1)
	
	url = OBJ_NEW('IDLnetUrl', URL_SCHEME='https', URL_HOST='solarnet.oma.be', URL_PATH=url_path, URL_QUERY=url_query, VERBOSE = verbose)
	data_raw = url->Get( /STRING_ARRAY )
	data = JSON_PARSE(data_raw, /TOSTRUCT)
	OBJ_DESTROY, url
	RETURN, data
END

FUNCTION get_url_query, filters, schema_url_path, offset = offset, limit = limit
	url_query = ''
	IF N_ELEMENTS(offset) GT 0 THEN url_query = url_query + "&offset=" + STRTRIM(offset,2)
	IF N_ELEMENTS(limit) GT 0 THEN url_query = url_query + "&limit=" + STRTRIM(limit,2)
	IF N_ELEMENTS(filters) EQ 0 THEN RETURN, url_query
	
	data = get_api_data(schema_url_path)
	fields = data.fields
	field_names = TAG_NAMES(fields)
	
	FOREACH filter_name, TAG_NAMES(filters), i DO BEGIN
		filter_value = filters.(i)
		index = WHERE(STRCMP(field_names, filter_name, /FOLD_CASE) EQ 1)
		IF index LT 0 THEN BEGIN
			MESSAGE, 'Unknown field '+ filter_name
		ENDIF ELSE BEGIN
			field = fields.(index)
			CASE field.type OF
				'string': url_query = url_query + string_filter(filter_name, filter_value)
				'integer': url_query = url_query + numeric_filter(filter_name, filter_value)
				'float': url_query = url_query + numeric_filter(filter_name, filter_value)
				'datetime': url_query = url_query + time_filter(filter_name, filter_value)
				'related': url_query = url_query + related_filter(filter_name, filter_value)
				ELSE : MESSAGE, 'Filter for type ' + field.type + ' has not been implemented!'
			ENDCASE
		ENDELSE
	ENDFOREACH
	
	RETURN, url_query
END

;+
;	:Author:  Benjamin Mampaey
;	:Keywords:
;		verbose : In, Optional, Type=boolean
;		*field_name* : In, Optional
;			*field_name* is any tag of a metadata struct. See https://github.com/bmampaey/SOLARNET-IDL-client for more information.
;	:Return: A list of dataset struct
;	:Uses: IDLnetUrl, JSON_PARSE
;	:History: See https://github.com/bmampaey/SOLARNET-IDL-client/commits/master
;	:Examples:
;		datasets = get_datasets(); Get all the datasets
;		datasets = get_datasets(name= 'Swap Level 1'); Get the swap dataset
;		datasets = get_datasets(telescope= 'SDO'); Get the datasets from the SDO telescope
;-

FUNCTION get_datasets, VERBOSE=verbose, _EXTRA = filters
	url_path = '/service/api/svo/dataset/'
	url_query = get_url_query(filters, url_path + 'schema/')
	data = get_api_data(url_path, url_query, VERBOSE=verbose)
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
;			*field_name* is any tag of a metadata struct. See https://github.com/bmampaey/SOLARNET-IDL-client for more information.
;	:Return: A list of metadata struct
;	:Uses: IDLnetUrl, JSON_PARSE
;	:History: See https://github.com/bmampaey/SOLARNET-IDL-client/commits/master
;	:Examples:
;		datasets = get_datasets(name= 'Swap Level 1'); Get the swap dataset
;		swap_dataset = datasets[0]
;		metadatas = get_metadatas(swap_dataset); Get some metadatas from the swap dataset
;		metadatas = get_metadatas(swap_dataset, date_obs={min: '2011-01-01'}); Get some metadatas from the swap dataset starting the 1st January 2011
;		metadatas = get_metadatas(swap_dataset, date_obs={min: '2011-01-01', max: '2011-02-01'}, exptime = 10, limit = 0); Get some  metadatas from the swap dataset for the month of January 2011 and with a exposure time of exactly 10 seconds
;-

FUNCTION get_metadatas, dataset, offset = offset, limit = limit, VERBOSE=verbose, _EXTRA = filters
	url_path = dataset.metadata.resource_uri
	url_query = get_url_query(filters, url_path + 'schema/', offset=offset, limit=limit)
	data = get_api_data(url_path, url_query, VERBOSE=verbose)
	offset = data.meta.offset + data.meta.limit
	RETURN, data.objects
END


;+
;	:Author:  Benjamin Mampaey
;	:Params:
;		metadata : in, required, type=struct
;			A metadata struct as returned by the get_metadatas function
;	:Keywords:
;		dir : In, Optional, Type=string
;			The directory where to download the file.
;		verbose : In, Optional, Type=boolean
;	:Return: The path to the downloaded file
;	:Uses: IDLnetUrl
;	:History: See https://github.com/bmampaey/SOLARNET-IDL-client/commits/master
;	:Examples:
;		PRINT, download_data(metadatas[0], dir = '/tmp')
;-

FUNCTION download_data, metadata, dir = dir, VERBOSE=verbose
	
	IF N_ELEMENTS(dir) EQ 0 THEN dir = '.'
	
	path = STRSPLIT(metadata.data_location.file_url, '/', /EXTRACT)
	filename = dir + PATH_SEP() + path[N_ELEMENTS(path) - 1]
	
	url = OBJ_NEW('IDLnetUrl', VERBOSE = verbose)
	RETURN, url->Get(FILENAME=filename, URL=metadata.data_location.file_url)
END
