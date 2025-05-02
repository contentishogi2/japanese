--unfortunately the source xml itself does not separate the meaning and reading associations into rmgroup though it has the provision for it

--select * from kanjidic--select * from kanjidic2 -- same data imported twice
--declare @handle int
--declare @k nvarchar(max)= (select top 1 converT(nvarchar(max),xmldata) from kanjidic2)
--exec sp_xml_preparedocument @handle output,@k;
--select * from
--openxml(@handle,'kanjidic2/character',2)
--with(literal nvarchar(max))
drop table if exists kanjidic_readingmeaning_map_20250502,#temp1;
declare @k xml= (select top 1 converT(nvarchar(max),xmldata) from kanjidic2)
;with meanings AS (SELECT
   k.character.value('../../../literal[1]', 'NVARCHAR(15)')collate japanese_bin2 literal,
   k.character.value('@m_lang[1]', 'NVARCHAR(2)')lang,
   --k.character.query('../..').value('.', 'NVARCHAR(500)')rmgroup,
   k.character.query('..').value('.', 'NVARCHAR(500)')rmgroup5,
   k.character.query('../..').value('.', 'NVARCHAR(500)')reading_meaning,
   k.character.query('.').value('.', 'NVARCHAR(150)')meaning,
   ROW_NUMBER()over(order by (select 1))m_order
FROM @k.nodes('kanjidic2/character/reading_meaning/rmgroup/meaning') AS k (character)
--where k.character.exist('/codepoint/cp_value/@cp_type="ucs"')=1
--where k.character.value('(reading_meaning/rmgroup/meaning[@m_lang!="es" and @m_lang!="pt" and @m_lang!="fr"])[1]', 'NVARCHAR(107)') is not null
--where isnull(k.character.value('(reading_meaning/rmgroup/meaning/@m_lang)[10]', 'NVARCHAR(2)'),'') not in ('es','pt','fr')
),readings AS (SELECT
   k.character.value('../../../literal[1]', 'NVARCHAR(15)')collate japanese_bin2 literal,
   k.character.value('@r_type[1]', 'NVARCHAR(6)')rtype,
   --k.character.query('../..').value('.', 'NVARCHAR(500)')rmgroup,
   --k.character.query('../../').value('.', 'NVARCHAR(500)')rmgroup2,
   --k.character.query('../.').value('.', 'NVARCHAR(500)')rmgroup3,
   --k.character.query('../').value('.', 'NVARCHAR(500)')rmgroup4,
   k.character.query('..').value('.', 'NVARCHAR(500)')rmgroup5,
   k.character.query('../..').value('.', 'NVARCHAR(500)')reading_meaning,
   k.character.query('.').value('.', 'NVARCHAR(150)')reading,
   ROW_NUMBER()over(order by (select 1))r_order
FROM @k.nodes('kanjidic2/character/reading_meaning/rmgroup/reading') AS k (character)
),nanori AS (SELECT
   k.character.value('../../literal[1]', 'NVARCHAR(15)')collate japanese_bin2 literal,
   --k.character.query('../..').value('.', 'NVARCHAR(500)')rmgroup,
   --k.character.query('../../').value('.', 'NVARCHAR(500)')rmgroup2,
   --k.character.query('../.').value('.', 'NVARCHAR(500)')rmgroup3,
   --k.character.query('../').value('.', 'NVARCHAR(500)')rmgroup4,
   k.character.query('..').value('.', 'NVARCHAR(500)')reading_meaning,
   k.character.query('.').value('.', 'NVARCHAR(150)')nanori,
   ROW_NUMBER()over(order by (select 1))n_order
FROM @k.nodes('kanjidic2/character/reading_meaning/nanori') AS k (character)
)
select m.literal,n.nanori,m.meaning,r.rtype,r.reading
,ROW_NUMBER()over(partition by m.literal order by m_order)m_order
,ROW_NUMBER()over(partition by m.literal order by r_order)r_order
into #temp1
from meanings m join readings r on r.literal=m.literal and r.rmgroup5=m.rmgroup5 and r.reading_meaning=m.reading_meaning
left join (select string_agg(nanori,',')within group(order by n_order)nanori,literal,reading_meaning from nanori group by literal,reading_meaning) n on n.literal=m.literal and n.reading_meaning=r.reading_meaning
where m.lang is null
and (rtype in ('ja_on','ja_kun')or rtype is null and nanori is not null)
order by m.literal,meaning,reading

drop table if exists #temp2
select literal,nanori,meaning,avg(m_order)m_order,rtype,STRING_AGG(reading,',')within group(order by r_order)reading
into #temp2 from #temp1
group by literal,meaning,nanori,rtype

select isnull(onyo.literal,kunyo.literal)literal,isnull(onyo.meaning,kunyo.meaning)meaning,isnull(onyo.m_order,kunyo.m_order)m_order
	,onyo.reading onyomi,kunyo.reading kunyomi,isnull(onyo.nanori,kunyo.nanori)nanori
into kanjidic_readingmeaning_map_20250502 from
(select literal,nanori,meaning,reading,m_order from #temp2 where rtype='ja_on') as onyo full outer join
(select literal,nanori,meaning,reading,m_order from #temp2 where rtype='ja_kun') as kunyo on onyo.literal=kunyo.literal and onyo.meaning=kunyo.meaning
where isnull(onyo.literal,kunyo.literal) is not null

drop table if exists #temp4,#temp5
select distinct replace(word,'_',' ') syn,replace(word,'_',' ')word
	into #temp4 from enthesaurus_main
union select distinct replace(syn,'_',' ')syn,replace(word,'_',' ')word
	from enthesaurus_syns s join enthesaurus_main m on s.word_id=m.word_id

select distinct convert(nvarchar(max),k.literal)literal
	,convert(nvarchar(max),replace(replace(left(k.onyomi,case when k.onyomi like'%,%'then charindex(',',k.onyomi)-1 else len(k.onyomi)end),N'-',''),N'.',''))onyomi
	,convert(nvarchar(max),replace(replace(left(k.kunyomi,case when k.kunyomi like'%,%'then charindex(',',k.kunyomi)-1 else len(k.kunyomi)end),N'-',''),N'.',''))kunyomi
	,k.nanori,syn meaning
	,word,m_order,ROW_NUMBER()over(partition by word,literal order by m_order)w_order
into #temp5
from kanjidic_readingmeaning_map_20250502 k
left join #temp4 s on syn = k.meaning
where s.syn is not null
--select * from #temp5 where literal=N'折' --order by meaning_order
--order by m_order
--select * from #temp4 where syn='louse'--but kanjidic has lice, an example of fail case

drop table if exists #temp6
select meaning
,count(*)-count(case when left(literal,1)='`'then 1 end)countmain,count(case when left(literal,1)='`'then 1 end)countex
,STRING_AGG(literal,'-')literal
,STRING_AGG(isnull(onyomi,'')+isnull(kunyomi,''),'-')within group(order by m_order,kunyomi,onyomi)onkunsutra
,STRING_AGG(isnull(onyomi,''),'-')onsutra
,STRING_AGG(isnull(kunyomi,''),'-')kunsutra
into #temp6 from
(select literal,meaning,onyomi,kunyomi,AVG(m_order)m_order
	from (select distinct literal,meaning,onyomi,kunyomi,AVG(m_order)m_order from #temp5 group by literal,meaning,onyomi,kunyomi
		--union select distinct '`'+literal,word meaning,onyomi,kunyomi,200*AVG(m_order)m_order from #temp5 x
		--			where not exists (select 1 from #temp5 y where y.literal=x.literal and y.meaning = x.word)
		--			group by literal,word,onyomi,kunyomi
		)b
	group by literal,meaning,onyomi,kunyomi)a
--where meaning='resign'
group by a.meaning --having count(distinct word)=1
order by count(*)-count(case when left(literal,1)='`'then 1 end) desc,count(*)desc
--select meaning,STRING_AGG(literal,'-')literal
--,STRING_AGG(isnull(onyomi,'')+isnull(kunyomi,''),'-')within group(order by m_order,kunyomi,onyomi)sutra
--from
--(select distinct literal,word meaning,onyomi,kunyomi,AVG(m_order)m_order from #temp5 group by literal,word,onyomi,kunyomi)a
--where meaning='resign'
--group by a.meaning --having count(distinct word)=1
--order by count(*) desc

select meaning,literal,countmain,countex,onn,kun,onkun from #temp6
cross apply(
select string_agg(onkun,'-')onkun from
(select distinct value onkun from string_split(onkunsutra,'-')a where value!='')a
--thought this would ensure that the order doesn't change but doesn't work.. so reading sutra is not aligned with literal sutra anymore
--(select onkun,min(rn)rn from
--	(select value onkun,row_number()over(order by (select 1))rn from string_split(onkunsutra,'-')a where value!='')a
--	group by onkun
--)b
)as onkun
cross apply(
select string_agg(onn,'-')onn from
	(select distinct value onn from string_split(onsutra,'-')a where value!='')a
)as onn
cross apply(
select string_agg(kun,'-')kun from
	(select distinct value kun from string_split(kunsutra,'-')a where value!='')a
)as kun
where meaning='daybreak'
