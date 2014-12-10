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

; Get some specific meta-datas from the swap dataset (all of it for the 1st January 2011)
meta_datas = get_meta_datas(swap_dataset, date_obs={min: '2011-01-01', max: '2011-01-02'})
FOR i = 0, N_ELEMENTS(meta_datas) - 1 DO PRINT, meta_datas[i].date_obs

; Download the data corresponding to some meta data
PRINT, download_data(meta_datas[0], dir = '/tmp')

```
