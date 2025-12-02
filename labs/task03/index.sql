create index if not exists idx_track_album_id
	on track (album_id);

create index if not exists idx_track_genre_id
	on track (genre_id);

explain
select
  t.name as track_name
, a.title as album_title
, g.name as genre_name
from track t
inner join album a 
            on t.album_id = a.album_id
inner join genre g 
            on t.genre_id = g.genre_id
order by g.name, a.title;