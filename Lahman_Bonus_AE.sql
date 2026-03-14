/* 
1. In this question, you'll get to practice correlated subqueries and learn about the LATERAL keyword. Note: This could be done using window functions, but we'll do it in a different way in order to revisit correlated subqueries and see another keyword - LATERAL.

1a. First, write a query utilizing a correlated subquery to find the team with the most wins from each league in 2016.
*/

SELECT teamid, yearid, name, lgid, w as wins
FROM teams as o
WHERE w = (
    SELECT MAX(w)
    FROM teams as i
    WHERE i.lgid = o.lgid
    and i.yearid = 2016
)
and yearid = 2016;


SELECT DISTINCT lgid, (SELECT teamid
					   FROM teams
					   WHERE t.lgid = teams.lgid 
					   AND yearid = 2016 
					   ORDER BY w DESC LIMIT 1)
FROM teams t
WHERE yearid = 2016;

/*
 1b. One downside to using correlated subqueries is that you can only return exactly one row and one column. This means, for example that if we wanted to pull in not just the teamid but also the number of wins, we couldn't do so using just a single subquery. (Try it and see the error you get). 
 
 Add another correlated subquery to your query on the previous part so that your result shows not just the teamid but also the number of wins by that team.
*/

SELECT DISTINCT lgid, 
				(SELECT teamid
				   FROM teams
				   WHERE t.lgid = teams.lgid 
				   AND yearid = 2016 
				   ORDER BY w DESC LIMIT 1),
				 (SELECT w
				   FROM teams
				   WHERE t.lgid = teams.lgid 
				   AND yearid = 2016 
				   ORDER BY w DESC LIMIT 1)
FROM teams t
WHERE yearid = 2016;

/*
 1c. If you are interested in pulling in the top (or bottom) values by group, you can also use the DISTINCT ON expression (https://www.postgresql.org/docs/9.5/sql-select.html#SQL-DISTINCT). 
 
 Rewrite your previous query into one which uses DISTINCT ON to return the top team by league in terms of number of wins in 2016. 
 
 Your query should return the league, the teamid, and the number of wins.
 */

SELECT distinct on (lgid) teamid, yearid, name, lgid, w as wins
from teams t
where yearid = 2016
order by lgid, w desc;

/*
1d. If we want to pull in more than one column in our correlated subquery, another way to do it is to make use of the LATERAL keyword (https://www.postgresql.org/docs/9.4/queries-table-expressions.html#QUERIES-LATERAL). 

This allows you to write subqueries in FROM that make reference to columns from previous FROM items. This gives us the flexibility to pull in or calculate multiple columns or multiple rows (or both). 

Rewrite your previous query using the LATERAL keyword so that your result shows the teamid and number of wins for the team with the most wins from each league in 2016.
 */


SELECT distinct
  best_teams.w as wins,
  t.lgid,
  best_teams.name,
  best_teams.teamid
FROM teams t
  JOIN LATERAL (
    SELECT teamid, w, name
	   FROM teams
	   WHERE t.lgid = teams.lgid 
	   AND yearid = 2016 
	   ORDER BY w DESC LIMIT 1
  ) best_teams ON true
where yearid = 2016;

SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL 
	  (SELECT teamid, w 
	   FROM teams
	   WHERE yearid = 2016
	   AND teams.lgid = leagues.lgid
	  ORDER BY w DESC
	  LIMIT 1) as top_teams;

/*
 1e. Finally, another advantage of the LATERAL keyword over using correlated subqueries is that you return multiple result rows. (Try to return more than one row in your correlated subquery from above and see what type of error you get). 
 
 Rewrite your query on the previous problem so that it returns the top 3 teams from each league in term of number of wins. Show the teamid and number of wins.
 */

SELECT *
FROM (SELECT DISTINCT lgid 
	  FROM teams
	  WHERE yearid = 2016) AS leagues,
	  LATERAL 
	  (SELECT teamid, w 
	   FROM teams
	   WHERE yearid = 2016
	   AND teams.lgid = leagues.lgid
	  ORDER BY w DESC
	  LIMIT 3) as top_teams;


/*
2a. Write a query which, for each player in the player table, assembles their birthyear, birthmonth, and birthday into a single column called birthdate which is of the date type.
*/

select make_date(birthyear, birthmonth, birthday) as birthdate
from people;

/*
2b. Use your previous result inside a subquery using LATERAL to calculate for each player their age at debut and age at retirement.

2c. Who is the youngest player to ever play in the major leagues?
 */

select namefirst || ' ' || namelast as playername, debut, finalgame, age(cast(debut as date), birthdate) as debut_age, age(cast(finalgame as date), birthdate) as retire_age
from people p,
lateral (select make_date(birthyear, birthmonth, birthday) as birthdate)
order by debut_age;

--Joe Nuxhall is the youngest player to ever play in the major leagues.

/*
2d. Who is the oldest player to player in the major leagues? You'll likely have a lot of null values resulting in your age at retirement calculation. 
Check out the documentation on sorting rows here https://www.postgresql.org/docs/8.3/queries-order.html about how you can change how null values are sorted.
 */

select namefirst || ' ' || namelast as playername, debut, finalgame, age(cast(debut as date), birthdate) as debut_age, age(cast(finalgame as date), birthdate) as retire_age
from people p,
lateral (select make_date(birthyear, birthmonth, birthday) as birthdate)
order by retire_age desc nulls last;

--Satchel Paige is the oldest player to play in the major leagues. He was 59 years 2 mons 18 days for his last game. 

/*
3a. Willie Mays holds the record of the most All Star Game starts with 18. How many players started in an All Star Game with Willie Mays? 

(A player started an All Star Game if they appear in the allstarfull table with a non-null startingpos value).
*/

-- Create a playedwith table to capture which players played all star games with which other players

with playedwith as (
	with allstarstarters as (select *
	from allstarfull
	inner join people p
		using(playerid)
	where startingpos is not null)
	SELECT
	    a1.playerid,
	    a1.namefirst || ' ' || a1.namelast AS other_player_name,
	    a1.yearid,
	    a2.playerid AS other_player_id,
	    a2.namefirst || ' ' || a2.namelast AS other_player_name
	FROM allstarstarters a1
	INNER JOIN allstarstarters a2
	    ON a1.yearid = a2.yearid
	WHERE a1.playerid != a2.playerid),
WITH RECURSIVE allstarmays AS(
SELECT
  f.playerid,
  f.other_player_name,
  0 AS mays_no,
  other_player_name || ' --(' || movie_title || ' - ' || movie_year || ')--> ' || playerid AS route
FROM playedwith AS f
WHERE playerid = (select playerid 
					from people
					where namefirst = 'Willie' 
					and namelast = 'Mays')
UNION ALL
SELECT
  p.playerid,
  f.other_player_name,
  p.mays_no + 1,
  f.other_player_name || ' --(' || movie_title || ' - ' || movie_year || ')--> ' || f.playerid ||E'\n'|| p.route
FROM playedwith AS p, allstarmays AS a
WHERE p.other_player_name = f.playerid 
AND a.mays_no < 6
)
SELECT 
  other_player_name AS Actor, 
  playerid AS connected_to, 
  mays_no, 
  route AS Connection
FROM allstarmays
LIMIT 1;

/* 
3b. How many players didn't start in an All Star Game with Willie Mays but started an All Star Game with another player who started an All Star Game with Willie Mays? 

For example, Graig Nettles never started an All Star Game with Willie Mayes, but he did star the 1975 All Star Game with Blue Vida who started the 1971 All Star Game with Willie Mays.
 */


/*
3c.  We'll call two players connected if they both started in the same All Star Game. Using this, we can find chains of players. 

For example, one chain from Carlton Fisk to Willie Mays is as follows: Carlton Fisk started in the 1973 All Star Game with Rod Carew who started in the 1972 All Star Game with Willie Mays. 

Find a chain of All Star starters connecting Babe Ruth to Willie Mays.
*/


/*
3d. How large a chain do you need to connect Derek Jeter to Willie Mays?
*/




