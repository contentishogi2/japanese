--drop table if exists enthesaurusjson
--SELECT CONVERT(nvarchar(max),MY_JSON,2)jsondata into enthesaurusjson
--     FROM OPENROWSET(BULK 'C:\Users\lenovo\Downloads\thesaurus-master\en_thesaurus.jsonl', SINGLE_CLOB) AS T(MY_JSON)
drop table if exists enthesaurus_main,enthesaurus_syns,enthesaurus_descs
select distinct row_number()over(order by word,wordnet_id)_id,dense_rank()over(order by word)word_id,pos,wordnet_id,word,[key]workd_key/*,[synonyms],[desc]*/
into enthesaurus_main from enthesaurusjson as json
cross apply openjson(jsondata)with(
pos nvarchar(max),
wordnet_id nvarchar(max),
word nvarchar(max),
[key] nvarchar(max),
[synonyms] nvarchar(max),
[desc] nvarchar(max)
)as thesaurus
--select count(*) from enthesaurus_main group by wordnet_id,[key] having count(*)>1
select distinct _id,word_id,dense_rank()over(partition by word_id order by syn)wordsyn_id,dense_rank()over(order by syn)syn_id
,syn
into enthesaurus_syns from enthesaurusjson as json 
cross apply openjson(jsondata)with(
pos nvarchar(max),
wordnet_id nvarchar(max),
word nvarchar(max),
[key] nvarchar(max),
[synonyms] nvarchar(max)'$.synonyms'as json
)as thesaurus
join enthesaurus_main m on m.wordnet_id=thesaurus.wordnet_id and m.word=thesaurus.word
outer apply openjson([synonyms])with(syn nvarchar(max)'$')

select distinct _id,word_id,descr
into enthesaurus_descs from enthesaurusjson as json 
cross apply openjson(jsondata)with(
pos nvarchar(max),
wordnet_id nvarchar(max),
word nvarchar(max),
[key] nvarchar(max),
[descs] nvarchar(max)'$.desc'as json
)as thesaurus
join enthesaurus_main m on m.wordnet_id=thesaurus.wordnet_id and m.word=thesaurus.word
outer apply openjson([descs])with([descr]nvarchar(max)'$')

select distinct * from enthesaurus_main m
join enthesaurus_syns s on m._id=s._id
--join enthesaurus_descs d on m._id=d._id
order by m.word,s.syn--,d.descr

select distinct word from enthesaurus_main m union
select distinct syn from enthesaurus_syns s