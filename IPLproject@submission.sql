##1.	List the different types of columns in table “ball_by_ball” (using information schema).
      SELECT 
           column_name,
  data_type
  FROM information_schema.columns
  WHERE table_name = 'ball_by_ball';

## 2.	What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table) ?
SELECT
    SUM(b.Runs_Scored) + COALESCE(SUM(e.Extra_Runs),0) AS Total_Runs
FROM matches m
JOIN ball_by_ball b
    ON m.Match_Id = b.Match_Id
LEFT JOIN extra_runs e
    ON b.Match_Id = e.Match_Id
   AND b.Over_Id = e.Over_Id
   AND b.Ball_Id = e.Ball_Id
   AND b.Innings_No = e.Innings_No
WHERE m.Season_Id = 6
  AND b.Team_Batting = 2;

## 3.	How many players were more than the age of 25 during season 2014?
SELECT COUNT(*) AS Players_Above_25
FROM player
WHERE TIMESTAMPDIFF(YEAR, DOB, '2014-01-01') > 25;

## 4.	How many matches did RCB win in 2013?
select count(*) as RCB_Wins
from matches m
join season s
on m.Season_Id = s.Season_Id
where s.Season_Year = 2013
  AND m.Match_Winner = 2;

## 5.	List the top 10 players according to their strike rate in the last 4 seasons?

SELECT
    p.Player_Name,
    SUM(b.Runs_Scored) AS Total_Runs,
    COUNT(*) AS Balls_Faced,
    ROUND((SUM(b.Runs_Scored) * 100.0) / COUNT(*), 2) AS Strike_Rate
FROM ball_by_ball b
JOIN matches m
    ON b.Match_Id = m.Match_Id
JOIN player p
    ON b.Striker = p.Player_Id
WHERE m.Season_Id IN (6,7,8,9)
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(*) > 0
ORDER BY Strike_Rate DESC
LIMIT 10;

## 6.	What are the average runs scored by each batsman considering all the seasons?

SELECT
         p.Player_Name,
         round(AVG(b.Runs_Scored),2) AS Avg_Runs
		FROM ball_by_ball b
        join player p
         ON b.Striker = p.Player_Id
         GROUP BY p.Player_Id, p.Player_Name
         order by Avg_Runs DESC;

## 7.	What are the average wickets taken by each bowler considering all the seasons?

select  p.Player_Name,
           round(COUNT(*)*1.0 / COUNT(DISTINCT m.Season_id),2) AS Avg_Wickets
	  FROM wicket_taken w
      join ball_by_ball b
      ON w.Match_Id = b.Match_Id
      AND w.Over_Id = b.Over_Id
      AND w.Ball_Id = b.Ball_Id
      join player P
      ON b.Bowler = p.Player_id
      join matches m
      on w.Match_Id = m.Match_Id
      group by p.Player_Id, p.Player_Name
	  order by Avg_Wickets DESC;

## 8.	List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average.
WITH batting AS (
    SELECT
        p.Player_Id,
        p.Player_Name,
        AVG(b.Runs_Scored) AS Avg_Runs
    FROM player p
    JOIN ball_by_ball b
        ON p.Player_Id = b.Striker
    GROUP BY p.Player_Id, p.Player_Name
),
bowling AS (
    SELECT
        p.Player_Id,
        COUNT(*) AS Total_Wickets
    FROM player p
    JOIN ball_by_ball b
        ON p.Player_Id = b.Bowler
    JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
    GROUP BY p.Player_Id
)

SELECT
    bt.Player_Name,
    bt.Avg_Runs,
    bw.Total_Wickets
FROM batting bt
JOIN bowling bw
    ON bt.Player_Id = bw.Player_Id
WHERE bt.Avg_Runs >
      (SELECT AVG(Runs_Scored) FROM ball_by_ball)
AND bw.Total_Wickets >
      (
        SELECT AVG(wicket_count)
        FROM (
            SELECT COUNT(*) AS wicket_count
            FROM wicket_taken
            GROUP BY Player_Out
        ) x
      )
ORDER BY bt.Avg_Runs DESC, bw.Total_Wickets DESC;

## 9.	Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.
SELECT
    v.Venue_Name,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE
            WHEN (m.Team_1 = 2 OR m.Team_2 = 2)
                 AND m.Match_Winner <> 2
            THEN 1
            ELSE 0
        END) AS Losses
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
WHERE m.Team_1 = 2
   OR m.Team_2 = 2
GROUP BY v.Venue_Name
ORDER BY Wins DESC;

## 10.	What is the impact of bowling style on wickets taken?
select 
    bs.Bowling_skill AS Bowling_Style,
    COUNT(*) AS Total_Wickets
FROM wicket_taken w
join ball_by_ball b
  ON w.Match_Id = b.Match_Id
  AND w.Over_Id = b.Over_Id
  AND w.Ball_Id = b.Ball_Id
JOIN player p
  on b.Bowler = p.Player_Id
join bowling_style bs
  on p.Bowling_skill = bs.Bowling_Id
group by bs.Bowling_skill
order by Total_Wickets DESC;
 
## 11.	Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken.

WITH season_stats AS
(
    SELECT
        m.Season_Id,
        b.Team_Batting AS Team_Id,
        SUM(b.Runs_Scored + IFNULL(er.Extra_Runs,0)) AS Total_Runs,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    LEFT JOIN extra_runs er
        ON b.Match_Id = er.Match_Id
       AND b.Over_Id = er.Over_Id
       AND b.Ball_Id = er.Ball_Id
    LEFT JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
    GROUP BY m.Season_Id, b.Team_Batting
)

SELECT
    Season_Id,
    Team_Id,
    Total_Runs,
    Total_Wickets,
    CASE
        WHEN Total_Runs >
             LAG(Total_Runs) OVER(PARTITION BY Team_Id ORDER BY Season_Id)
         AND Total_Wickets >
             LAG(Total_Wickets) OVER(PARTITION BY Team_Id ORDER BY Season_Id)
        THEN 'Better'

        WHEN Total_Runs <
             LAG(Total_Runs) OVER(PARTITION BY Team_Id ORDER BY Season_Id)
         AND Total_Wickets <
             LAG(Total_Wickets) OVER(PARTITION BY Team_Id ORDER BY Season_Id)
        THEN 'Worse'

        ELSE 'Mixed'
    END AS Performance_Status
FROM season_stats;

## 13.	Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.

WITH bowler_venue_stats AS
(
    SELECT
        v.Venue_Name,
        p.Player_Name,
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    JOIN matches m
        ON w.Match_Id = m.Match_Id
    JOIN venue v
        ON m.Venue_Id = v.Venue_Id
    JOIN player p
        ON b.Bowler = p.Player_Id
    GROUP BY v.Venue_Name, p.Player_Id, p.Player_Name
)

SELECT
    Venue_Name,
    Player_Name,
    Avg_Wickets,
    DENSE_RANK() OVER
    (
        PARTITION BY Venue_Name
        ORDER BY Avg_Wickets DESC
    ) AS Venue_Rank
FROM bowler_venue_stats
ORDER BY Venue_Name, Venue_Rank;

## 14.	Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)?

SELECT
    p.Player_Name,
    s.Season_Year,
    SUM(b.Runs_Scored) AS Total_Runs
FROM ball_by_ball b
JOIN matches m
    ON b.Match_Id = m.Match_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
JOIN player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Name, s.Season_Year
ORDER BY p.Player_Name, s.Season_Year;

#### SUBJECTIVE
# 1.	How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?
# for batsman
SELECT
    p.Player_Name,
    SUM(b.Runs_Scored) AS Total_Runs
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Id, p.Player_Name
ORDER BY Total_Runs DESC;
# for bowller
SELECT
    td.Toss_Name,
    COUNT(*) AS Total_Matches,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS Toss_Winner_Won,
    ROUND(
        SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Win_Percentage
FROM matches m
JOIN toss_decision td
    ON m.Toss_Decide = td.Toss_Id
GROUP BY td.Toss_Name;

# 2.	Suggest some of the players who would be best fit for the team.

WITH batting AS (
    SELECT
        p.Player_Id,
        p.Player_Name,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM ball_by_ball b
    JOIN player p
        ON b.Striker = p.Player_Id
    GROUP BY p.Player_Id, p.Player_Name
),
bowling AS (
    SELECT
        p.Player_Id,
        COUNT(*) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    JOIN player p
        ON b.Bowler = p.Player_Id
    GROUP BY p.Player_Id
)

SELECT
    bt.Player_Name,
    bt.Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets
FROM batting bt
LEFT JOIN bowling bw
    ON bt.Player_Id = bw.Player_Id
ORDER BY bt.Total_Runs DESC,
         Total_Wickets DESC;

## 3.	What are some of the parameters that should be focused on while selecting the players?

WITH batting AS
(
    SELECT
        p.Player_Id,
        p.Player_Name,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM ball_by_ball b
    JOIN player p
        ON b.Striker = p.Player_Id
    GROUP BY p.Player_Id, p.Player_Name
),

bowling AS
(
    SELECT
        p.Player_Id,
        COUNT(*) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    JOIN player p
        ON b.Bowler = p.Player_Id
    GROUP BY p.Player_Id
)

SELECT
    bt.Player_Name,
    bt.Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets
FROM batting bt
LEFT JOIN bowling bw
    ON bt.Player_Id = bw.Player_Id
WHERE COALESCE(bw.Total_Wickets,0) > 0
ORDER BY Total_Runs DESC, Total_Wickets DESC;

## 4.	Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)

WITH batting AS
(
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
),
bowling AS
(
    SELECT
        b.Bowler AS Player_Id,
        COUNT(*) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    GROUP BY b.Bowler
)

SELECT
    p.Player_Name,
    bt.Total_Runs,
    bw.Total_Wickets
FROM player p
JOIN batting bt
    ON p.Player_Id = bt.Player_Id
JOIN bowling bw
    ON p.Player_Id = bw.Player_Id
ORDER BY bt.Total_Runs DESC, bw.Total_Wickets DESC;

## 5.	Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualization)?
WITH batting AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
),

bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(*) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    GROUP BY b.Bowler
)

SELECT
    p.Player_Name,
    COALESCE(bt.Total_Runs, 0) AS Total_Runs,
    COALESCE(bw.Total_Wickets, 0) AS Total_Wickets
FROM player p
LEFT JOIN batting bt
    ON p.Player_Id = bt.Player_Id
LEFT JOIN bowling bw
    ON p.Player_Id = bw.Player_Id
WHERE COALESCE(bt.Total_Runs,0) > 500
   OR COALESCE(bw.Total_Wickets,0) > 20
ORDER BY Total_Runs DESC, Total_Wickets DESC;

## 6.	What would you suggest to RCB before going to the mega auction?


WITH batting AS (
    SELECT
        p.Player_Id,
        p.Player_Name,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM ball_by_ball b
    JOIN player p
        ON b.Striker = p.Player_Id
    GROUP BY p.Player_Id, p.Player_Name
),
bowling AS (
    SELECT
        p.Player_Id,
        COUNT(*) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    JOIN player p
        ON b.Bowler = p.Player_Id
    GROUP BY p.Player_Id
)
SELECT
    bt.Player_Name,
    COALESCE(bt.Total_Runs,0) AS Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets
FROM batting bt
LEFT JOIN bowling bw
    ON bt.Player_Id = bw.Player_Id
ORDER BY Total_Runs DESC, Total_Wickets DESC;


WITH batting AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
),

bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(*) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    GROUP BY b.Bowler
)

SELECT
    p.Player_Name,
    COALESCE(bt.Total_Runs, 0) AS Total_Runs,
    COALESCE(bw.Total_Wickets, 0) AS Total_Wickets
FROM player p
LEFT JOIN batting bt
    ON p.Player_Id = bt.Player_Id
LEFT JOIN bowling bw
    ON p.Player_Id = bw.Player_Id
WHERE COALESCE(bt.Total_Runs,0) > 500
   OR COALESCE(bw.Total_Wickets,0) > 20
ORDER BY Total_Runs DESC, Total_Wickets DESC;

##  6.	What would you suggest to RCB before going to the mega auction?

WITH batting AS (
    SELECT
        p.Player_Id,
        p.Player_Name,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM ball_by_ball b
    JOIN player p
        ON b.Striker = p.Player_Id
    GROUP BY p.Player_Id, p.Player_Name
),
bowling AS (
    SELECT
        p.Player_Id,
        COUNT(*) AS Total_Wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
        ON w.Match_Id = b.Match_Id
       AND w.Over_Id = b.Over_Id
       AND w.Ball_Id = b.Ball_Id
    JOIN player p
        ON b.Bowler = p.Player_Id
    GROUP BY p.Player_Id
)
SELECT
    bt.Player_Name,
    COALESCE(bt.Total_Runs,0) AS Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets
FROM batting bt
LEFT JOIN bowling bw
    ON bt.Player_Id = bw.Player_Id
ORDER BY Total_Runs DESC, Total_Wickets DESC;

## 7.	What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies?

SELECT
    m.Match_Id,
    v.Venue_Name,
    s.Season_Year,
    t1.Team_Name AS Batting_Team,
    SUM(bb.Runs_Scored) + COALESCE(SUM(er.Extra_Runs),0) AS Total_Runs
FROM ball_by_ball bb
JOIN matches m
    ON bb.Match_Id = m.Match_Id
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
JOIN team t1
    ON bb.Team_Batting = t1.Team_Id
LEFT JOIN extra_runs er
    ON bb.Match_Id = er.Match_Id
    AND bb.Over_Id = er.Over_Id
    AND bb.Ball_Id = er.Ball_Id
    AND bb.Innings_No = er.Innings_No
GROUP BY
    m.Match_Id,
    v.Venue_Name,
    s.Season_Year,
    t1.Team_Name
ORDER BY Total_Runs DESC;

## 8.	Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.

SELECT
    t.Team_Name,
    v.Venue_Name,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Win_Percentage
FROM matches m
JOIN team t
    ON t.Team_Id IN (m.Team_1, m.Team_2)
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
WHERE t.Team_Name LIKE '%Bangalore%'
GROUP BY t.Team_Name, v.Venue_Name
ORDER BY Win_Percentage DESC;

## 9.	Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.

SELECT
    s.Season_Year,
    COUNT(*) AS Matches_Played,
    SUM(
        CASE
            WHEN m.Match_Winner = t.Team_Id THEN 1
            ELSE 0
        END
    ) AS Matches_Won,
    ROUND(
        SUM(
            CASE
                WHEN m.Match_Winner = t.Team_Id THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*), 2
    ) AS Win_Percentage
FROM matches m
JOIN season s
    ON m.Season_Id = s.Season_Id
JOIN team t
    ON t.Team_Name = 'Royal Challengers Bangalore'
WHERE t.Team_Id IN (m.Team_1, m.Team_2)
GROUP BY s.Season_Year
ORDER BY s.Season_Year;

##   11.	In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

UPDATE matches
SET Opponent_Team = 'Delhi_Daredevils'
WHERE Opponent_Team = 'Delhi_Capitals';
