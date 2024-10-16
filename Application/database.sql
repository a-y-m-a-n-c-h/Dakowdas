PGDMP     3    +                 {            Dakowdas    15.4    15.4 �    #           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            $           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            %           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            &           1262    114836    Dakowdas    DATABASE     �   CREATE DATABASE "Dakowdas" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'English_United States.1252';
    DROP DATABASE "Dakowdas";
                postgres    false                       1255    115251    check_2_participants()    FUNCTION     �   CREATE FUNCTION public.check_2_participants() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(SELECT Count(*) FROM public."Joins" WHERE "battleID" = NEW. "battleID")>1 THEN
		RETURN NULL;
	End IF;
	Return NEW;
END;
$$;
 -   DROP FUNCTION public.check_2_participants();
       public          postgres    false                        1255    115280    check_contest_eligibility()    FUNCTION     �  CREATE FUNCTION public.check_contest_eligibility() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    contestant_rating integer;
    contest_division integer;
BEGIN
	SELECT "rating"
    INTO contestant_rating
    FROM public."Contestant" co
    WHERE co."contestantUsername" = NEW."contestantUsername";
	
	SELECT "divsion"
    INTO contest_division
    FROM public."Contest" con
    WHERE con."roundNumber" = NEW."roundNumber";
	
	IF ((contestant_rating > 1900 AND contest_division <= 2)
        OR
        (contestant_rating <= 1900 AND contestant_rating >= 1600 AND contest_division<= 3 AND contest_division > 1)
        OR
        (contestant_rating < 1600 AND contest_division > 1)
    ) THEN
		RETURN NEW;
	End IF;
	Return NULL;
END;
$$;
 2   DROP FUNCTION public.check_contest_eligibility();
       public          postgres    false                       1255    123069    check_problems_per_battles()    FUNCTION     �   CREATE FUNCTION public.check_problems_per_battles() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(SELECT Count(*) FROM public."ConsistsOf" WHERE "battleID" = NEW. "battleID")>2 THEN
		RETURN NULL;
	End IF;
	Return NEW;
END;
$$;
 3   DROP FUNCTION public.check_problems_per_battles();
       public          postgres    false                       1255    123040    hack_score_update()    FUNCTION     Z  CREATE FUNCTION public.hack_score_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    contestant_username text;
BEGIN 
    IF ((SELECT "verdict" FROM public."Hack" WHERE "hackID" = NEW."hackID") = 'Hack Successful') THEN
        UPDATE public."Submission"
        SET verdict = 'Hacked'
        WHERE "submissionID" = NEW."submissionID";
        
        SELECT c."contestantUsername" 
        INTO contestant_username
        FROM public."Contestant" c 
        JOIN public."User" u ON u."username" = c."contestantUsername" 
        JOIN public."Submits" s ON s."username" = u."username" 
        WHERE s."submissionID" = NEW."submissionID";

        CALL update_rating(contestant_username);

        UPDATE public."CompetesIn"
        SET score = score - hash_diffculty_level(
            (SELECT p."difficultyLevel" 
             FROM public."ProgrammingProblem" p 
             JOIN public."Submits" st ON p."problemID" = st."problemNumber" 
             WHERE st."submissionID" = NEW."submissionID")
        )
        WHERE ("contestantUsername" = contestant_username)
            AND ("roundNumber" = (
                SELECT p."roundNumber" 
                FROM public."ProgrammingProblem" p 
                JOIN public."Submits" st ON p."problemID" = st."problemNumber" 
                WHERE st."submissionID" = NEW."submissionID"
            ));     

        UPDATE public."CompetesIn"
        SET score = score + 50
        WHERE ("contestantUsername" = NEW."hackerUsername")
            AND ("roundNumber" = (
                SELECT p."roundNumber" 
                FROM public."ProgrammingProblem" p 
                JOIN public."Submits" st ON p."problemID" = st."problemNumber" 
                WHERE st."submissionID" = NEW."submissionID"
            ));    

        CALL update_rating(NEW."hackerUsername");
    END IF;
    RETURN NEW;
END;
$$;
 *   DROP FUNCTION public.hack_score_update();
       public          postgres    false                       1255    115261    hash_diffculty_level(character)    FUNCTION     �  CREATE FUNCTION public.hash_diffculty_level(difficultylevel character) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN 
	IF (difficultyLevel = 'A') THEN
		return 30;
	ELSIF (difficultyLevel = 'B') THEN
		return 40;
	ELSIF (difficultyLevel = 'C') THEN
		return 50;
	ELSIF (difficultyLevel = 'D') THEN
		return 60;
	ELSIF (difficultyLevel = 'E') THEN
		return 70;
	ELSE
		return 80;
	END IF;
END;
	
$$;
 F   DROP FUNCTION public.hash_diffculty_level(difficultylevel character);
       public          postgres    false                       1255    123055    rating_to_bracket(integer)    FUNCTION     �  CREATE FUNCTION public.rating_to_bracket(rating integer) RETURNS text
    LANGUAGE plpgsql
    AS $$ 
BEGIN 
	if (rating <= 1900) then
		return 'Newbie';
	elsif (rating <=1399) then
		return 'Pupil';
	elsif (rating <=1599) then
		return 'Specialist';
	elsif (rating <= 1899) then
		return 'Expert';
	elsif (rating <= 2099) then
		return 'Candidate Master';
	elsif (rating <=2299) then
		return 'Master';
	elsif (rating <= 2399) then
		return 'International Master';
	elsif (rating <= 2599) then
		return 'Grandmaster';
	elsif (rating <= 2999) then
		return 'International Grandmaster';
	else
		return 'Legendary Grandmaster';
	END IF;
END;
$$;
 8   DROP FUNCTION public.rating_to_bracket(rating integer);
       public          postgres    false                       1255    123042    rating_update_for_1_contest()    FUNCTION       CREATE FUNCTION public.rating_update_for_1_contest() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN 
	UPDATE public."Contestant"
	SET "rating" = GREATEST(0, "rating" + NEW."score")
	where "contestantUsername" = NEW."contestantUsername";
	
	RETURN NEW;
END;
	
$$;
 4   DROP FUNCTION public.rating_update_for_1_contest();
       public          postgres    false                       1255    123066    search_topic(text)    FUNCTION     �  CREATE FUNCTION public.search_topic(topic text) RETURNS TABLE(username text, title text, _content text, _timestamp timestamp without time zone, votes bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY  
		Select v."username", v."title", v."content", v."timestamp", v."votes"
		from BlogEntry_View as v
		join public."Hashtag" as h on h."blogEntryID" = v."blogEntryID" 
		where h."tag" = topic
		order by "votes" DESC
Limit 5;
END;
$$;
 /   DROP FUNCTION public.search_topic(topic text);
       public          postgres    false                       1255    123067    update_rating(text) 	   PROCEDURE     �   CREATE PROCEDURE public.update_rating(IN usern text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE public."Contestant" 
	set "rating" = GREATEST ((Select sum(c."score") from public."CompetesIn" as c where c."contestantUsername"=usern),0);
END;	
$$;
 4   DROP PROCEDURE public.update_rating(IN usern text);
       public          postgres    false                       1255    123045 *   view_friends_in_competition(text, integer)    FUNCTION     y  CREATE FUNCTION public.view_friends_in_competition(contestantusername text, round integer) RETURNS TABLE(frinedusername text, friendscore integer, friendrank integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
	friend_record RECORD;
BEGIN
	IF EXISTS(SELECT * FROM public."CompetesIn" c where c."contestantUsername" = contestantusername and c."roundNumber" = round) then
		FOR friend_record in 
			SELECT "contestantUsername", "score" , "rank" 
					from public."CompetesIn"
					where (("contestantUsername" =
					--CASE 1: contestantusername is friend1
					((Select b."friend2Username" from public."Befriends" b 
					  			join public."User" u on b."friend2Username" = u."username" 
					  			join public."Contestant" c on c."contestantUsername" = u."username" 
					  			join public."CompetesIn" ci on c."contestantUsername" = ci."contestantUsername" 
					  			where b."friend1Username"=contestantusername and ci."roundNumber" = round)
	 				UNION
					 --CASE 2: contestantusername is friend2
					 (Select b."friend1Username" from public."Befriends" b 
					  			join public."User" u on b."friend1Username" = u."username" 
					  			join public."Contestant" c on c."contestantUsername" = u."username" 
					  			join public."CompetesIn" ci on c."contestantUsername" = ci."contestantUsername" 
					  			where b."friend2Username"=contestantusername and ci."roundNumber" = round)
	 				 )	)	
					 and
					 "roundNumber" = round					 
					 )
					 ORDER BY "score" DESC
		LOOP
			frinedUsername:=friend_record."contestantUsername";
			friendScore:=friend_record."score";
			friendRank:=friend_record."rank";
			RETURN NEXT;
		END LOOP;
	END IF;
END;
$$;
 Z   DROP FUNCTION public.view_friends_in_competition(contestantusername text, round integer);
       public          postgres    false            �            1259    115096    AddsNotification    TABLE     �   CREATE TABLE public."AddsNotification" (
    "creatorUsername" text NOT NULL,
    "roundNumber" integer NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "notificationContent" text
);
 &   DROP TABLE public."AddsNotification";
       public         heap    postgres    false            �            1259    114952    Admin    TABLE     l   CREATE TABLE public."Admin" (
    username text NOT NULL,
    role text,
    "contributionScore" integer
);
    DROP TABLE public."Admin";
       public         heap    postgres    false            �            1259    114939    Announcement    TABLE     �  CREATE TABLE public."Announcement" (
    "announcementID" integer NOT NULL,
    username text,
    language text,
    content text,
    "timestamp" timestamp without time zone,
    CONSTRAINT check_announcement_language CHECK (((language = 'English'::text) OR (language = 'Arabic'::text) OR (language = 'French'::text) OR (language = 'German'::text) OR (language = 'Italian'::text) OR (language = 'Spanish'::text) OR (language = 'Russian'::text)))
);
 "   DROP TABLE public."Announcement";
       public         heap    postgres    false            �            1259    114938    Announcement_announcementID_seq    SEQUENCE     �   CREATE SEQUENCE public."Announcement_announcementID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public."Announcement_announcementID_seq";
       public          postgres    false    223            '           0    0    Announcement_announcementID_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public."Announcement_announcementID_seq" OWNED BY public."Announcement"."announcementID";
          public          postgres    false    222            �            1259    115176    Battle    TABLE     �   CREATE TABLE public."Battle" (
    "battleID" integer NOT NULL,
    "startTimestamp" timestamp without time zone,
    "endTimestamp" timestamp without time zone
);
    DROP TABLE public."Battle";
       public         heap    postgres    false            �            1259    115175    Battle_battleID_seq    SEQUENCE     �   CREATE SEQUENCE public."Battle_battleID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public."Battle_battleID_seq";
       public          postgres    false    245            (           0    0    Battle_battleID_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public."Battle_battleID_seq" OWNED BY public."Battle"."battleID";
          public          postgres    false    244            �            1259    114861 	   Befriends    TABLE     �   CREATE TABLE public."Befriends" (
    "friend1Username" text NOT NULL,
    "friend2Username" text NOT NULL,
    "timestamp" timestamp without time zone
);
    DROP TABLE public."Befriends";
       public         heap    postgres    false            �            1259    114879 	   BlogEntry    TABLE     �   CREATE TABLE public."BlogEntry" (
    "blogEntryID" integer NOT NULL,
    username text,
    title text,
    content text,
    "timestamp" timestamp without time zone
);
    DROP TABLE public."BlogEntry";
       public         heap    postgres    false            �            1259    114878    BlogEntry_blogEntryID_seq    SEQUENCE     �   CREATE SEQUENCE public."BlogEntry_blogEntryID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public."BlogEntry_blogEntryID_seq";
       public          postgres    false    218            )           0    0    BlogEntry_blogEntryID_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public."BlogEntry_blogEntryID_seq" OWNED BY public."BlogEntry"."blogEntryID";
          public          postgres    false    217            �            1259    114904    Comments    TABLE     �   CREATE TABLE public."Comments" (
    "blogEntryID" integer NOT NULL,
    username text NOT NULL,
    content text,
    "timestamp" timestamp without time zone NOT NULL
);
    DROP TABLE public."Comments";
       public         heap    postgres    false            �            1259    115026 
   CompetesIn    TABLE       CREATE TABLE public."CompetesIn" (
    "contestantUsername" text NOT NULL,
    "roundNumber" integer NOT NULL,
    score integer,
    rank integer,
    "timestampOfRegistration" timestamp without time zone,
    CONSTRAINT check_positive_rank CHECK ((rank > 0))
);
     DROP TABLE public."CompetesIn";
       public         heap    postgres    false            �            1259    115199 
   ConsistsOf    TABLE     h   CREATE TABLE public."ConsistsOf" (
    "battleID" integer NOT NULL,
    "problemID" integer NOT NULL
);
     DROP TABLE public."ConsistsOf";
       public         heap    postgres    false            �            1259    115001    Contest    TABLE     ?  CREATE TABLE public."Contest" (
    "roundNumber" integer NOT NULL,
    name text,
    divsion integer,
    "startTimestamp" timestamp without time zone,
    length time without time zone,
    description text,
    CONSTRAINT check_division CHECK (((divsion = 1) OR (divsion = 2) OR (divsion = 3) OR (divsion = 4)))
);
    DROP TABLE public."Contest";
       public         heap    postgres    false            �            1259    114976    ContestCreator    TABLE     m   CREATE TABLE public."ContestCreator" (
    "creatorUsername" text NOT NULL,
    "assessmentScore" integer
);
 $   DROP TABLE public."ContestCreator";
       public         heap    postgres    false            �            1259    115000    Contest_roundNumber_seq    SEQUENCE     �   CREATE SEQUENCE public."Contest_roundNumber_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public."Contest_roundNumber_seq";
       public          postgres    false    229            *           0    0    Contest_roundNumber_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public."Contest_roundNumber_seq" OWNED BY public."Contest"."roundNumber";
          public          postgres    false    228            �            1259    114988 
   Contestant    TABLE     �   CREATE TABLE public."Contestant" (
    "contestantUsername" text NOT NULL,
    rating integer,
    CONSTRAINT check_positive_rating CHECK ((rating >= 0))
);
     DROP TABLE public."Contestant";
       public         heap    postgres    false            �            1259    115145    Hack    TABLE     �   CREATE TABLE public."Hack" (
    "hackID" integer NOT NULL,
    test text,
    verdict text,
    "timestamp" timestamp without time zone
);
    DROP TABLE public."Hack";
       public         heap    postgres    false            �            1259    115144    Hack_hackID_seq    SEQUENCE     �   CREATE SEQUENCE public."Hack_hackID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public."Hack_hackID_seq";
       public          postgres    false    242            +           0    0    Hack_hackID_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public."Hack_hackID_seq" OWNED BY public."Hack"."hackID";
          public          postgres    false    241            �            1259    115153    Hacks    TABLE     �   CREATE TABLE public."Hacks" (
    "hackerUsername" text NOT NULL,
    "submissionID" integer NOT NULL,
    "hackID" integer NOT NULL
);
    DROP TABLE public."Hacks";
       public         heap    postgres    false            �            1259    114892    Hashtag    TABLE     ]   CREATE TABLE public."Hashtag" (
    "blogEntryID" integer NOT NULL,
    tag text NOT NULL
);
    DROP TABLE public."Hashtag";
       public         heap    postgres    false            �            1259    115182    Joins    TABLE     u   CREATE TABLE public."Joins" (
    username text NOT NULL,
    "battleID" integer NOT NULL,
    "isWinner" boolean
);
    DROP TABLE public."Joins";
       public         heap    postgres    false            �            1259    114844    Messages    TABLE     �   CREATE TABLE public."Messages" (
    "senderUsername" text NOT NULL,
    "receiverUsername" text NOT NULL,
    content text,
    "timestamp" timestamp without time zone NOT NULL
);
    DROP TABLE public."Messages";
       public         heap    postgres    false            �            1259    115009 	   Organizes    TABLE     m   CREATE TABLE public."Organizes" (
    "creatorUsername" text NOT NULL,
    "roundNumber" integer NOT NULL
);
    DROP TABLE public."Organizes";
       public         heap    postgres    false            �            1259    115044    ProgrammingProblem    TABLE     M  CREATE TABLE public."ProgrammingProblem" (
    "problemID" integer NOT NULL,
    "difficultyLevel" character(1),
    title text,
    description text,
    "timeLimit" integer,
    "memoryLimit" integer,
    "roundNumber" integer,
    CONSTRAINT check_difficultylevel CHECK ((("difficultyLevel" = 'A'::bpchar) OR ("difficultyLevel" = 'B'::bpchar) OR ("difficultyLevel" = 'C'::bpchar) OR ("difficultyLevel" = 'D'::bpchar) OR ("difficultyLevel" = 'E'::bpchar) OR ("difficultyLevel" = 'F'::bpchar))),
    CONSTRAINT check_positive_limits CHECK ((("timeLimit" > 0) AND ("memoryLimit" > 0)))
);
 (   DROP TABLE public."ProgrammingProblem";
       public         heap    postgres    false            �            1259    115043     ProgrammingProblem_problemID_seq    SEQUENCE     �   CREATE SEQUENCE public."ProgrammingProblem_problemID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public."ProgrammingProblem_problemID_seq";
       public          postgres    false    233            ,           0    0     ProgrammingProblem_problemID_seq    SEQUENCE OWNED BY     k   ALTER SEQUENCE public."ProgrammingProblem_problemID_seq" OWNED BY public."ProgrammingProblem"."problemID";
          public          postgres    false    232            �            1259    114964    Responsibilities    TABLE     p   CREATE TABLE public."Responsibilities" (
    "adminUsername" text NOT NULL,
    responsibility text NOT NULL
);
 &   DROP TABLE public."Responsibilities";
       public         heap    postgres    false            �            1259    115236    Solution    TABLE        CREATE TABLE public."Solution" (
    "problemID" integer NOT NULL,
    "solutionID" integer NOT NULL,
    "sourceCode" text
);
    DROP TABLE public."Solution";
       public         heap    postgres    false            �            1259    115235    Solution_solutionID_seq    SEQUENCE     �   CREATE SEQUENCE public."Solution_solutionID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public."Solution_solutionID_seq";
       public          postgres    false    249            -           0    0    Solution_solutionID_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public."Solution_solutionID_seq" OWNED BY public."Solution"."solutionID";
          public          postgres    false    248            �            1259    115114 
   Submission    TABLE     �  CREATE TABLE public."Submission" (
    "submissionID" integer NOT NULL,
    "programmingLanguage" text,
    "sourceCode" text,
    verdict text,
    "timestamp" timestamp without time zone,
    CONSTRAINT check_problem_language CHECK ((("programmingLanguage" = 'GNU G++20 11.2.0'::text) OR ("programmingLanguage" = 'GNU G++17 7.3.0'::text) OR ("programmingLanguage" = 'GNU G++14 6.4.0'::text) OR ("programmingLanguage" = 'Python 2.7.18'::text) OR ("programmingLanguage" = 'Python 3.8.10'::text) OR ("programmingLanguage" = 'Java 11.0.6'::text) OR ("programmingLanguage" = 'Java 17 64bit'::text) OR ("programmingLanguage" = 'Java 21 64bit'::text) OR ("programmingLanguage" = 'OCaml 4.02.1'::text) OR ("programmingLanguage" = 'C# 8'::text) OR ("programmingLanguage" = 'C# 10'::text))),
    CONSTRAINT check_verdict CHECK (((verdict = 'Accepted'::text) OR (verdict = 'Wrong Answer'::text) OR (verdict = 'Hacked'::text)))
);
     DROP TABLE public."Submission";
       public         heap    postgres    false            �            1259    115113    Submission_submissionID_seq    SEQUENCE     �   CREATE SEQUENCE public."Submission_submissionID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public."Submission_submissionID_seq";
       public          postgres    false    239            .           0    0    Submission_submissionID_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public."Submission_submissionID_seq" OWNED BY public."Submission"."submissionID";
          public          postgres    false    238            �            1259    115122    Submits    TABLE     �   CREATE TABLE public."Submits" (
    username text NOT NULL,
    "submissionID" integer NOT NULL,
    "problemNumber" integer NOT NULL
);
    DROP TABLE public."Submits";
       public         heap    postgres    false            �            1259    115057    Tag    TABLE     W   CREATE TABLE public."Tag" (
    "problemID" integer NOT NULL,
    tag text NOT NULL
);
    DROP TABLE public."Tag";
       public         heap    postgres    false            �            1259    115071    TestCase    TABLE     �   CREATE TABLE public."TestCase" (
    "problemID" integer NOT NULL,
    "testCaseNumber" integer NOT NULL,
    input text,
    "expectedOutput" text
);
    DROP TABLE public."TestCase";
       public         heap    postgres    false            �            1259    115070    TestCase_testCaseNumber_seq    SEQUENCE     �   CREATE SEQUENCE public."TestCase_testCaseNumber_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public."TestCase_testCaseNumber_seq";
       public          postgres    false    236            /           0    0    TestCase_testCaseNumber_seq    SEQUENCE OWNED BY     a   ALTER SEQUENCE public."TestCase_testCaseNumber_seq" OWNED BY public."TestCase"."testCaseNumber";
          public          postgres    false    235            �            1259    114837    User    TABLE     .  CREATE TABLE public."User" (
    username text NOT NULL,
    email text,
    passwod text,
    "firstName" text,
    "lastName" text,
    country text,
    "registrationDate" date,
    CONSTRAINT check_valid_email CHECK (regexp_like(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);
    DROP TABLE public."User";
       public         heap    postgres    false            �            1259    114921    VotesOn    TABLE     b   CREATE TABLE public."VotesOn" (
    "blogEntryID" integer NOT NULL,
    username text NOT NULL
);
    DROP TABLE public."VotesOn";
       public         heap    postgres    false            �            1259    123018    announcement_view    VIEW     P  CREATE VIEW public.announcement_view AS
 SELECT "Announcement"."announcementID",
    "Announcement".username,
    "Announcement".language,
    "Announcement".content,
    "Announcement"."timestamp",
    age(now(), ("Announcement"."timestamp")::timestamp with time zone) AS time_elapsed_since_announcement
   FROM public."Announcement";
 $   DROP VIEW public.announcement_view;
       public          postgres    false    223    223    223    223    223            �            1259    123022    blogentry_view    VIEW       CREATE VIEW public.blogentry_view AS
 SELECT b."blogEntryID",
    b.username,
    b.title,
    b.content,
    b."timestamp",
    ( SELECT count(*) AS count
           FROM public."VotesOn" v
          WHERE (v."blogEntryID" = b."blogEntryID")) AS votes
   FROM public."BlogEntry" b;
 !   DROP VIEW public.blogentry_view;
       public          postgres    false    218    218    218    221    218    218            �            1259    123031    contest_view    VIEW     6  CREATE VIEW public.contest_view AS
 SELECT "Contest"."roundNumber",
    "Contest".name,
    "Contest".divsion,
    "Contest"."startTimestamp",
    "Contest".length,
    "Contest".description,
    age(("Contest"."startTimestamp")::timestamp with time zone, now()) AS time_before_start
   FROM public."Contest";
    DROP VIEW public.contest_view;
       public          postgres    false    229    229    229    229    229    229            �            1259    123056    contestant_view    VIEW     �   CREATE VIEW public.contestant_view AS
 SELECT "Contestant"."contestantUsername",
    "Contestant".rating,
    public.rating_to_bracket("Contestant".rating) AS bracket
   FROM public."Contestant";
 "   DROP VIEW public.contestant_view;
       public          postgres    false    272    227    227            �            1259    123026    programmingproblem_view    VIEW     �  CREATE VIEW public.programmingproblem_view AS
 SELECT p."problemID",
    p."difficultyLevel",
    p.title,
    p.description,
    p."timeLimit",
    p."memoryLimit",
    p."roundNumber",
    ( SELECT count(*) AS count
           FROM (public."Submission" s
             JOIN public."Submits" ss ON ((ss."submissionID" = s."submissionID")))
          WHERE ((ss."problemNumber" = p."problemID") AND (s.verdict = 'Accepted'::text))) AS number_of_correct_submissions
   FROM public."ProgrammingProblem" p;
 *   DROP VIEW public.programmingproblem_view;
       public          postgres    false    240    233    233    233    233    233    233    233    239    239    240            �            1259    123013 	   user_view    VIEW     �  CREATE VIEW public.user_view AS
 SELECT u.username,
    u.email,
    u.passwod,
    u."firstName",
    u."lastName",
    u.country,
    u."registrationDate",
    ( SELECT count(*) AS count
           FROM public."Befriends" b
          WHERE ((b."friend1Username" = u.username) OR (b."friend2Username" = u.username))) AS numberoffriends,
    ( SELECT count(DISTINCT p."problemID") AS count
           FROM ((public."ProgrammingProblem" p
             JOIN public."Submits" ss ON (((ss."problemNumber" = p."problemID") AND (ss.username = u.username))))
             JOIN public."Submission" s ON ((ss."submissionID" = s."submissionID")))
          WHERE (s.verdict = 'Accepted'::text)) AS numberofproblemssolved
   FROM public."User" u;
    DROP VIEW public.user_view;
       public          postgres    false    214    214    216    214    214    214    214    240    240    240    239    239    233    216    214            �           2604    114942    Announcement announcementID    DEFAULT     �   ALTER TABLE ONLY public."Announcement" ALTER COLUMN "announcementID" SET DEFAULT nextval('public."Announcement_announcementID_seq"'::regclass);
 N   ALTER TABLE public."Announcement" ALTER COLUMN "announcementID" DROP DEFAULT;
       public          postgres    false    223    222    223            �           2604    115179    Battle battleID    DEFAULT     x   ALTER TABLE ONLY public."Battle" ALTER COLUMN "battleID" SET DEFAULT nextval('public."Battle_battleID_seq"'::regclass);
 B   ALTER TABLE public."Battle" ALTER COLUMN "battleID" DROP DEFAULT;
       public          postgres    false    244    245    245            �           2604    114882    BlogEntry blogEntryID    DEFAULT     �   ALTER TABLE ONLY public."BlogEntry" ALTER COLUMN "blogEntryID" SET DEFAULT nextval('public."BlogEntry_blogEntryID_seq"'::regclass);
 H   ALTER TABLE public."BlogEntry" ALTER COLUMN "blogEntryID" DROP DEFAULT;
       public          postgres    false    217    218    218            �           2604    115004    Contest roundNumber    DEFAULT     �   ALTER TABLE ONLY public."Contest" ALTER COLUMN "roundNumber" SET DEFAULT nextval('public."Contest_roundNumber_seq"'::regclass);
 F   ALTER TABLE public."Contest" ALTER COLUMN "roundNumber" DROP DEFAULT;
       public          postgres    false    228    229    229            �           2604    115148    Hack hackID    DEFAULT     p   ALTER TABLE ONLY public."Hack" ALTER COLUMN "hackID" SET DEFAULT nextval('public."Hack_hackID_seq"'::regclass);
 >   ALTER TABLE public."Hack" ALTER COLUMN "hackID" DROP DEFAULT;
       public          postgres    false    241    242    242            �           2604    115047    ProgrammingProblem problemID    DEFAULT     �   ALTER TABLE ONLY public."ProgrammingProblem" ALTER COLUMN "problemID" SET DEFAULT nextval('public."ProgrammingProblem_problemID_seq"'::regclass);
 O   ALTER TABLE public."ProgrammingProblem" ALTER COLUMN "problemID" DROP DEFAULT;
       public          postgres    false    233    232    233            �           2604    115239    Solution solutionID    DEFAULT     �   ALTER TABLE ONLY public."Solution" ALTER COLUMN "solutionID" SET DEFAULT nextval('public."Solution_solutionID_seq"'::regclass);
 F   ALTER TABLE public."Solution" ALTER COLUMN "solutionID" DROP DEFAULT;
       public          postgres    false    248    249    249            �           2604    115117    Submission submissionID    DEFAULT     �   ALTER TABLE ONLY public."Submission" ALTER COLUMN "submissionID" SET DEFAULT nextval('public."Submission_submissionID_seq"'::regclass);
 J   ALTER TABLE public."Submission" ALTER COLUMN "submissionID" DROP DEFAULT;
       public          postgres    false    239    238    239            �           2604    115074    TestCase testCaseNumber    DEFAULT     �   ALTER TABLE ONLY public."TestCase" ALTER COLUMN "testCaseNumber" SET DEFAULT nextval('public."TestCase_testCaseNumber_seq"'::regclass);
 J   ALTER TABLE public."TestCase" ALTER COLUMN "testCaseNumber" DROP DEFAULT;
       public          postgres    false    236    235    236                      0    115096    AddsNotification 
   TABLE DATA           r   COPY public."AddsNotification" ("creatorUsername", "roundNumber", "timestamp", "notificationContent") FROM stdin;
    public          postgres    false    237   J                0    114952    Admin 
   TABLE DATA           F   COPY public."Admin" (username, role, "contributionScore") FROM stdin;
    public          postgres    false    224   �                0    114939    Announcement 
   TABLE DATA           d   COPY public."Announcement" ("announcementID", username, language, content, "timestamp") FROM stdin;
    public          postgres    false    223   X                0    115176    Battle 
   TABLE DATA           P   COPY public."Battle" ("battleID", "startTimestamp", "endTimestamp") FROM stdin;
    public          postgres    false    245   j      �          0    114861 	   Befriends 
   TABLE DATA           X   COPY public."Befriends" ("friend1Username", "friend2Username", "timestamp") FROM stdin;
    public          postgres    false    216   	                0    114879 	   BlogEntry 
   TABLE DATA           [   COPY public."BlogEntry" ("blogEntryID", username, title, content, "timestamp") FROM stdin;
    public          postgres    false    218   :
                0    114904    Comments 
   TABLE DATA           S   COPY public."Comments" ("blogEntryID", username, content, "timestamp") FROM stdin;
    public          postgres    false    220   �                0    115026 
   CompetesIn 
   TABLE DATA           s   COPY public."CompetesIn" ("contestantUsername", "roundNumber", score, rank, "timestampOfRegistration") FROM stdin;
    public          postgres    false    231   d                0    115199 
   ConsistsOf 
   TABLE DATA           ?   COPY public."ConsistsOf" ("battleID", "problemID") FROM stdin;
    public          postgres    false    247   �                0    115001    Contest 
   TABLE DATA           h   COPY public."Contest" ("roundNumber", name, divsion, "startTimestamp", length, description) FROM stdin;
    public          postgres    false    229   &      	          0    114976    ContestCreator 
   TABLE DATA           P   COPY public."ContestCreator" ("creatorUsername", "assessmentScore") FROM stdin;
    public          postgres    false    226   e      
          0    114988 
   Contestant 
   TABLE DATA           D   COPY public."Contestant" ("contestantUsername", rating) FROM stdin;
    public          postgres    false    227                   0    115145    Hack 
   TABLE DATA           F   COPY public."Hack" ("hackID", test, verdict, "timestamp") FROM stdin;
    public          postgres    false    242   �                0    115153    Hacks 
   TABLE DATA           M   COPY public."Hacks" ("hackerUsername", "submissionID", "hackID") FROM stdin;
    public          postgres    false    243   5                0    114892    Hashtag 
   TABLE DATA           7   COPY public."Hashtag" ("blogEntryID", tag) FROM stdin;
    public          postgres    false    219   �                0    115182    Joins 
   TABLE DATA           C   COPY public."Joins" (username, "battleID", "isWinner") FROM stdin;
    public          postgres    false    246   �      �          0    114844    Messages 
   TABLE DATA           `   COPY public."Messages" ("senderUsername", "receiverUsername", content, "timestamp") FROM stdin;
    public          postgres    false    215   |                0    115009 	   Organizes 
   TABLE DATA           G   COPY public."Organizes" ("creatorUsername", "roundNumber") FROM stdin;
    public          postgres    false    230   �                 0    115044    ProgrammingProblem 
   TABLE DATA           �   COPY public."ProgrammingProblem" ("problemID", "difficultyLevel", title, description, "timeLimit", "memoryLimit", "roundNumber") FROM stdin;
    public          postgres    false    233   �                 0    114964    Responsibilities 
   TABLE DATA           M   COPY public."Responsibilities" ("adminUsername", responsibility) FROM stdin;
    public          postgres    false    225   5+                 0    115236    Solution 
   TABLE DATA           M   COPY public."Solution" ("problemID", "solutionID", "sourceCode") FROM stdin;
    public          postgres    false    249   ',                0    115114 
   Submission 
   TABLE DATA           q   COPY public."Submission" ("submissionID", "programmingLanguage", "sourceCode", verdict, "timestamp") FROM stdin;
    public          postgres    false    239   4.                0    115122    Submits 
   TABLE DATA           N   COPY public."Submits" (username, "submissionID", "problemNumber") FROM stdin;
    public          postgres    false    240   S0                0    115057    Tag 
   TABLE DATA           1   COPY public."Tag" ("problemID", tag) FROM stdin;
    public          postgres    false    234   o2                0    115071    TestCase 
   TABLE DATA           \   COPY public."TestCase" ("problemID", "testCaseNumber", input, "expectedOutput") FROM stdin;
    public          postgres    false    236   �3      �          0    114837    User 
   TABLE DATA           p   COPY public."User" (username, email, passwod, "firstName", "lastName", country, "registrationDate") FROM stdin;
    public          postgres    false    214   s5                0    114921    VotesOn 
   TABLE DATA           <   COPY public."VotesOn" ("blogEntryID", username) FROM stdin;
    public          postgres    false    221   j<      0           0    0    Announcement_announcementID_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public."Announcement_announcementID_seq"', 1, true);
          public          postgres    false    222            1           0    0    Battle_battleID_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public."Battle_battleID_seq"', 10, true);
          public          postgres    false    244            2           0    0    BlogEntry_blogEntryID_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public."BlogEntry_blogEntryID_seq"', 1, false);
          public          postgres    false    217            3           0    0    Contest_roundNumber_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public."Contest_roundNumber_seq"', 1, false);
          public          postgres    false    228            4           0    0    Hack_hackID_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public."Hack_hackID_seq"', 11, true);
          public          postgres    false    241            5           0    0     ProgrammingProblem_problemID_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public."ProgrammingProblem_problemID_seq"', 1, false);
          public          postgres    false    232            6           0    0    Solution_solutionID_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public."Solution_solutionID_seq"', 60, true);
          public          postgres    false    248            7           0    0    Submission_submissionID_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public."Submission_submissionID_seq"', 1, false);
          public          postgres    false    238            8           0    0    TestCase_testCaseNumber_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public."TestCase_testCaseNumber_seq"', 60, true);
          public          postgres    false    235            .           2606    115102 &   AddsNotification AddsNotification_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public."AddsNotification"
    ADD CONSTRAINT "AddsNotification_pkey" PRIMARY KEY ("timestamp", "roundNumber", "creatorUsername");
 T   ALTER TABLE ONLY public."AddsNotification" DROP CONSTRAINT "AddsNotification_pkey";
       public            postgres    false    237    237    237                       2606    114958    Admin Admin_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public."Admin"
    ADD CONSTRAINT "Admin_pkey" PRIMARY KEY (username);
 >   ALTER TABLE ONLY public."Admin" DROP CONSTRAINT "Admin_pkey";
       public            postgres    false    224                       2606    114946    Announcement Announcement_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public."Announcement"
    ADD CONSTRAINT "Announcement_pkey" PRIMARY KEY ("announcementID");
 L   ALTER TABLE ONLY public."Announcement" DROP CONSTRAINT "Announcement_pkey";
       public            postgres    false    223            :           2606    115181    Battle Battle_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public."Battle"
    ADD CONSTRAINT "Battle_pkey" PRIMARY KEY ("battleID");
 @   ALTER TABLE ONLY public."Battle" DROP CONSTRAINT "Battle_pkey";
       public            postgres    false    245                       2606    114867    Befriends Befriends_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public."Befriends"
    ADD CONSTRAINT "Befriends_pkey" PRIMARY KEY ("friend1Username", "friend2Username");
 F   ALTER TABLE ONLY public."Befriends" DROP CONSTRAINT "Befriends_pkey";
       public            postgres    false    216    216                       2606    114886    BlogEntry BlogEntry_pkey 
   CONSTRAINT     e   ALTER TABLE ONLY public."BlogEntry"
    ADD CONSTRAINT "BlogEntry_pkey" PRIMARY KEY ("blogEntryID");
 F   ALTER TABLE ONLY public."BlogEntry" DROP CONSTRAINT "BlogEntry_pkey";
       public            postgres    false    218                       2606    123047    Comments Comments_pkey 
   CONSTRAINT     z   ALTER TABLE ONLY public."Comments"
    ADD CONSTRAINT "Comments_pkey" PRIMARY KEY ("blogEntryID", username, "timestamp");
 D   ALTER TABLE ONLY public."Comments" DROP CONSTRAINT "Comments_pkey";
       public            postgres    false    220    220    220            &           2606    115032    CompetesIn CompetesIn_pkey 
   CONSTRAINT     }   ALTER TABLE ONLY public."CompetesIn"
    ADD CONSTRAINT "CompetesIn_pkey" PRIMARY KEY ("contestantUsername", "roundNumber");
 H   ALTER TABLE ONLY public."CompetesIn" DROP CONSTRAINT "CompetesIn_pkey";
       public            postgres    false    231    231            >           2606    115203    ConsistsOf ConsistsOf_pkey 
   CONSTRAINT     q   ALTER TABLE ONLY public."ConsistsOf"
    ADD CONSTRAINT "ConsistsOf_pkey" PRIMARY KEY ("battleID", "problemID");
 H   ALTER TABLE ONLY public."ConsistsOf" DROP CONSTRAINT "ConsistsOf_pkey";
       public            postgres    false    247    247                       2606    114982 "   ContestCreator ContestCreator_pkey 
   CONSTRAINT     s   ALTER TABLE ONLY public."ContestCreator"
    ADD CONSTRAINT "ContestCreator_pkey" PRIMARY KEY ("creatorUsername");
 P   ALTER TABLE ONLY public."ContestCreator" DROP CONSTRAINT "ContestCreator_pkey";
       public            postgres    false    226            "           2606    115008    Contest Contest_pkey 
   CONSTRAINT     a   ALTER TABLE ONLY public."Contest"
    ADD CONSTRAINT "Contest_pkey" PRIMARY KEY ("roundNumber");
 B   ALTER TABLE ONLY public."Contest" DROP CONSTRAINT "Contest_pkey";
       public            postgres    false    229                        2606    114994    Contestant Contestant_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public."Contestant"
    ADD CONSTRAINT "Contestant_pkey" PRIMARY KEY ("contestantUsername");
 H   ALTER TABLE ONLY public."Contestant" DROP CONSTRAINT "Contestant_pkey";
       public            postgres    false    227            6           2606    115152    Hack Hack_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public."Hack"
    ADD CONSTRAINT "Hack_pkey" PRIMARY KEY ("hackID");
 <   ALTER TABLE ONLY public."Hack" DROP CONSTRAINT "Hack_pkey";
       public            postgres    false    242            8           2606    115159    Hacks Hacks_pkey 
   CONSTRAINT     z   ALTER TABLE ONLY public."Hacks"
    ADD CONSTRAINT "Hacks_pkey" PRIMARY KEY ("hackerUsername", "submissionID", "hackID");
 >   ALTER TABLE ONLY public."Hacks" DROP CONSTRAINT "Hacks_pkey";
       public            postgres    false    243    243    243                       2606    114898    Hashtag Hashtag_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public."Hashtag"
    ADD CONSTRAINT "Hashtag_pkey" PRIMARY KEY ("blogEntryID", tag);
 B   ALTER TABLE ONLY public."Hashtag" DROP CONSTRAINT "Hashtag_pkey";
       public            postgres    false    219    219            <           2606    115188    Joins Joins_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public."Joins"
    ADD CONSTRAINT "Joins_pkey" PRIMARY KEY ("battleID", username);
 >   ALTER TABLE ONLY public."Joins" DROP CONSTRAINT "Joins_pkey";
       public            postgres    false    246    246                       2606    114850    Messages Messages_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public."Messages"
    ADD CONSTRAINT "Messages_pkey" PRIMARY KEY ("senderUsername", "receiverUsername", "timestamp");
 D   ALTER TABLE ONLY public."Messages" DROP CONSTRAINT "Messages_pkey";
       public            postgres    false    215    215    215            $           2606    115015    Organizes Organizes_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public."Organizes"
    ADD CONSTRAINT "Organizes_pkey" PRIMARY KEY ("creatorUsername", "roundNumber");
 F   ALTER TABLE ONLY public."Organizes" DROP CONSTRAINT "Organizes_pkey";
       public            postgres    false    230    230            (           2606    115051 *   ProgrammingProblem ProgrammingProblem_pkey 
   CONSTRAINT     u   ALTER TABLE ONLY public."ProgrammingProblem"
    ADD CONSTRAINT "ProgrammingProblem_pkey" PRIMARY KEY ("problemID");
 X   ALTER TABLE ONLY public."ProgrammingProblem" DROP CONSTRAINT "ProgrammingProblem_pkey";
       public            postgres    false    233                       2606    114970 &   Responsibilities Responsibilities_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public."Responsibilities"
    ADD CONSTRAINT "Responsibilities_pkey" PRIMARY KEY ("adminUsername", responsibility);
 T   ALTER TABLE ONLY public."Responsibilities" DROP CONSTRAINT "Responsibilities_pkey";
       public            postgres    false    225    225            @           2606    115243    Solution Solution_pkey 
   CONSTRAINT     o   ALTER TABLE ONLY public."Solution"
    ADD CONSTRAINT "Solution_pkey" PRIMARY KEY ("solutionID", "problemID");
 D   ALTER TABLE ONLY public."Solution" DROP CONSTRAINT "Solution_pkey";
       public            postgres    false    249    249            0           2606    115121    Submission Submission_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public."Submission"
    ADD CONSTRAINT "Submission_pkey" PRIMARY KEY ("submissionID");
 H   ALTER TABLE ONLY public."Submission" DROP CONSTRAINT "Submission_pkey";
       public            postgres    false    239            2           2606    115128    Submits Submits_pkey 
   CONSTRAINT     }   ALTER TABLE ONLY public."Submits"
    ADD CONSTRAINT "Submits_pkey" PRIMARY KEY ("problemNumber", "submissionID", username);
 B   ALTER TABLE ONLY public."Submits" DROP CONSTRAINT "Submits_pkey";
       public            postgres    false    240    240    240            *           2606    115063    Tag Tag_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public."Tag"
    ADD CONSTRAINT "Tag_pkey" PRIMARY KEY ("problemID", tag);
 :   ALTER TABLE ONLY public."Tag" DROP CONSTRAINT "Tag_pkey";
       public            postgres    false    234    234            ,           2606    115078    TestCase TestCase_pkey 
   CONSTRAINT     s   ALTER TABLE ONLY public."TestCase"
    ADD CONSTRAINT "TestCase_pkey" PRIMARY KEY ("problemID", "testCaseNumber");
 D   ALTER TABLE ONLY public."TestCase" DROP CONSTRAINT "TestCase_pkey";
       public            postgres    false    236    236            
           2606    114843    User User_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (username);
 <   ALTER TABLE ONLY public."User" DROP CONSTRAINT "User_pkey";
       public            postgres    false    214                       2606    114927    VotesOn Votes_On_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public."VotesOn"
    ADD CONSTRAINT "Votes_On_pkey" PRIMARY KEY ("blogEntryID", username);
 C   ALTER TABLE ONLY public."VotesOn" DROP CONSTRAINT "Votes_On_pkey";
       public            postgres    false    221    221            4           2606    115270 '   Submits unique_submission_id_constraint 
   CONSTRAINT     n   ALTER TABLE ONLY public."Submits"
    ADD CONSTRAINT unique_submission_id_constraint UNIQUE ("submissionID");
 S   ALTER TABLE ONLY public."Submits" DROP CONSTRAINT unique_submission_id_constraint;
       public            postgres    false    240            d           2620    115281 ,   CompetesIn check_contest_eligibility_trigger    TRIGGER     �   CREATE TRIGGER check_contest_eligibility_trigger BEFORE INSERT ON public."CompetesIn" FOR EACH ROW EXECUTE FUNCTION public.check_contest_eligibility();
 G   DROP TRIGGER check_contest_eligibility_trigger ON public."CompetesIn";
       public          postgres    false    256    231            h           2620    123070 1   ConsistsOf check_two_or_three_problems_per_battle    TRIGGER     �   CREATE TRIGGER check_two_or_three_problems_per_battle BEFORE INSERT ON public."ConsistsOf" FOR EACH ROW EXECUTE FUNCTION public.check_problems_per_battles();
 L   DROP TRIGGER check_two_or_three_problems_per_battle ON public."ConsistsOf";
       public          postgres    false    274    247            g           2620    115252 '   Joins check_two_participants_per_battle    TRIGGER     �   CREATE TRIGGER check_two_participants_per_battle BEFORE INSERT ON public."Joins" FOR EACH ROW EXECUTE FUNCTION public.check_2_participants();
 B   DROP TRIGGER check_two_participants_per_battle ON public."Joins";
       public          postgres    false    246    257            e           2620    123043 "   CompetesIn new_competition_trigger    TRIGGER     �   CREATE TRIGGER new_competition_trigger AFTER INSERT ON public."CompetesIn" FOR EACH ROW EXECUTE FUNCTION public.rating_update_for_1_contest();
 =   DROP TRIGGER new_competition_trigger ON public."CompetesIn";
       public          postgres    false    271    231            f           2620    123041    Hacks successful_hack_trigger    TRIGGER     �   CREATE TRIGGER successful_hack_trigger AFTER INSERT ON public."Hacks" FOR EACH ROW EXECUTE FUNCTION public.hack_score_update();
 8   DROP TRIGGER successful_hack_trigger ON public."Hacks";
       public          postgres    false    243    276            M           2606    114971    Responsibilities admin_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Responsibilities"
    ADD CONSTRAINT admin_fk FOREIGN KEY ("adminUsername") REFERENCES public."Admin"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 E   ALTER TABLE ONLY public."Responsibilities" DROP CONSTRAINT admin_fk;
       public          postgres    false    224    225    3354            _           2606    115189    Joins battle_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Joins"
    ADD CONSTRAINT battle_fk FOREIGN KEY ("battleID") REFERENCES public."Battle"("battleID") ON UPDATE CASCADE ON DELETE CASCADE;
 ;   ALTER TABLE ONLY public."Joins" DROP CONSTRAINT battle_fk;
       public          postgres    false    3386    245    246            a           2606    115204    ConsistsOf battle_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."ConsistsOf"
    ADD CONSTRAINT battle_fk FOREIGN KEY ("battleID") REFERENCES public."Battle"("battleID") ON UPDATE CASCADE ON DELETE CASCADE;
 @   ALTER TABLE ONLY public."ConsistsOf" DROP CONSTRAINT battle_fk;
       public          postgres    false    245    247    3386            F           2606    114899    Hashtag blogEntry_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Hashtag"
    ADD CONSTRAINT "blogEntry_fk" FOREIGN KEY ("blogEntryID") REFERENCES public."BlogEntry"("blogEntryID") ON UPDATE CASCADE ON DELETE CASCADE;
 B   ALTER TABLE ONLY public."Hashtag" DROP CONSTRAINT "blogEntry_fk";
       public          postgres    false    3344    219    218            G           2606    114911    Comments blogEntry_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Comments"
    ADD CONSTRAINT "blogEntry_fk" FOREIGN KEY ("blogEntryID") REFERENCES public."BlogEntry"("blogEntryID") ON UPDATE CASCADE ON DELETE CASCADE;
 C   ALTER TABLE ONLY public."Comments" DROP CONSTRAINT "blogEntry_fk";
       public          postgres    false    3344    218    220            I           2606    114928    VotesOn blog_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."VotesOn"
    ADD CONSTRAINT blog_fk FOREIGN KEY ("blogEntryID") REFERENCES public."BlogEntry"("blogEntryID") ON UPDATE CASCADE ON DELETE CASCADE;
 ;   ALTER TABLE ONLY public."VotesOn" DROP CONSTRAINT blog_fk;
       public          postgres    false    3344    218    221            P           2606    115016    Organizes contest_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Organizes"
    ADD CONSTRAINT contest_fk FOREIGN KEY ("roundNumber") REFERENCES public."Contest"("roundNumber") ON UPDATE CASCADE ON DELETE CASCADE;
 @   ALTER TABLE ONLY public."Organizes" DROP CONSTRAINT contest_fk;
       public          postgres    false    230    3362    229            R           2606    115033    CompetesIn contest_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."CompetesIn"
    ADD CONSTRAINT contest_fk FOREIGN KEY ("roundNumber") REFERENCES public."Contest"("roundNumber") ON UPDATE CASCADE ON DELETE CASCADE;
 A   ALTER TABLE ONLY public."CompetesIn" DROP CONSTRAINT contest_fk;
       public          postgres    false    231    229    3362            T           2606    115052    ProgrammingProblem contest_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."ProgrammingProblem"
    ADD CONSTRAINT contest_fk FOREIGN KEY ("roundNumber") REFERENCES public."Contest"("roundNumber") ON UPDATE CASCADE ON DELETE CASCADE;
 I   ALTER TABLE ONLY public."ProgrammingProblem" DROP CONSTRAINT contest_fk;
       public          postgres    false    233    229    3362            W           2606    115103    AddsNotification contest_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."AddsNotification"
    ADD CONSTRAINT contest_fk FOREIGN KEY ("roundNumber") REFERENCES public."Contest"("roundNumber") ON UPDATE CASCADE ON DELETE CASCADE;
 G   ALTER TABLE ONLY public."AddsNotification" DROP CONSTRAINT contest_fk;
       public          postgres    false    237    3362    229            S           2606    115038    CompetesIn contestant_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."CompetesIn"
    ADD CONSTRAINT contestant_fk FOREIGN KEY ("contestantUsername") REFERENCES public."Contestant"("contestantUsername") ON UPDATE CASCADE ON DELETE CASCADE;
 D   ALTER TABLE ONLY public."CompetesIn" DROP CONSTRAINT contestant_fk;
       public          postgres    false    227    3360    231            Q           2606    115021    Organizes creator_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Organizes"
    ADD CONSTRAINT creator_fk FOREIGN KEY ("creatorUsername") REFERENCES public."ContestCreator"("creatorUsername") ON UPDATE CASCADE ON DELETE CASCADE;
 @   ALTER TABLE ONLY public."Organizes" DROP CONSTRAINT creator_fk;
       public          postgres    false    230    226    3358            X           2606    115108    AddsNotification creator_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."AddsNotification"
    ADD CONSTRAINT creator_fk FOREIGN KEY ("creatorUsername") REFERENCES public."ContestCreator"("creatorUsername") ON UPDATE CASCADE ON DELETE CASCADE;
 G   ALTER TABLE ONLY public."AddsNotification" DROP CONSTRAINT creator_fk;
       public          postgres    false    226    237    3358            C           2606    114868    Befriends friend1_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Befriends"
    ADD CONSTRAINT friend1_fk FOREIGN KEY ("friend1Username") REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 @   ALTER TABLE ONLY public."Befriends" DROP CONSTRAINT friend1_fk;
       public          postgres    false    3338    214    216            D           2606    114873    Befriends friend2_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Befriends"
    ADD CONSTRAINT friend2_fk FOREIGN KEY ("friend2Username") REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 @   ALTER TABLE ONLY public."Befriends" DROP CONSTRAINT friend2_fk;
       public          postgres    false    214    3338    216            \           2606    115160    Hacks hack_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Hacks"
    ADD CONSTRAINT hack_fk FOREIGN KEY ("hackID") REFERENCES public."Hack"("hackID") ON UPDATE CASCADE ON DELETE CASCADE;
 9   ALTER TABLE ONLY public."Hacks" DROP CONSTRAINT hack_fk;
       public          postgres    false    3382    243    242            ]           2606    115165    Hacks hacker_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Hacks"
    ADD CONSTRAINT hacker_fk FOREIGN KEY ("hackerUsername") REFERENCES public."Contestant"("contestantUsername") ON UPDATE CASCADE ON DELETE CASCADE;
 ;   ALTER TABLE ONLY public."Hacks" DROP CONSTRAINT hacker_fk;
       public          postgres    false    227    3360    243            U           2606    115064    Tag problem_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Tag"
    ADD CONSTRAINT problem_fk FOREIGN KEY ("problemID") REFERENCES public."ProgrammingProblem"("problemID") ON UPDATE CASCADE ON DELETE CASCADE;
 :   ALTER TABLE ONLY public."Tag" DROP CONSTRAINT problem_fk;
       public          postgres    false    234    233    3368            V           2606    115079    TestCase problem_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."TestCase"
    ADD CONSTRAINT problem_fk FOREIGN KEY ("problemID") REFERENCES public."ProgrammingProblem"("problemID") ON UPDATE CASCADE ON DELETE CASCADE;
 ?   ALTER TABLE ONLY public."TestCase" DROP CONSTRAINT problem_fk;
       public          postgres    false    233    3368    236            Y           2606    115129    Submits problem_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Submits"
    ADD CONSTRAINT problem_fk FOREIGN KEY ("problemNumber") REFERENCES public."ProgrammingProblem"("problemID") ON UPDATE CASCADE ON DELETE CASCADE;
 >   ALTER TABLE ONLY public."Submits" DROP CONSTRAINT problem_fk;
       public          postgres    false    240    233    3368            b           2606    115209    ConsistsOf problem_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."ConsistsOf"
    ADD CONSTRAINT problem_fk FOREIGN KEY ("problemID") REFERENCES public."ProgrammingProblem"("problemID") ON UPDATE CASCADE ON DELETE CASCADE;
 A   ALTER TABLE ONLY public."ConsistsOf" DROP CONSTRAINT problem_fk;
       public          postgres    false    233    247    3368            c           2606    115244    Solution problem_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Solution"
    ADD CONSTRAINT problem_fk FOREIGN KEY ("problemID") REFERENCES public."ProgrammingProblem"("problemID") ON UPDATE CASCADE ON DELETE CASCADE;
 ?   ALTER TABLE ONLY public."Solution" DROP CONSTRAINT problem_fk;
       public          postgres    false    249    3368    233            Z           2606    115134    Submits submission_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Submits"
    ADD CONSTRAINT submission_fk FOREIGN KEY ("submissionID") REFERENCES public."Submission"("submissionID") ON UPDATE CASCADE ON DELETE CASCADE;
 A   ALTER TABLE ONLY public."Submits" DROP CONSTRAINT submission_fk;
       public          postgres    false    3376    240    239            ^           2606    115170    Hacks submission_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Hacks"
    ADD CONSTRAINT submission_fk FOREIGN KEY ("submissionID") REFERENCES public."Submission"("submissionID") ON UPDATE CASCADE ON DELETE CASCADE;
 ?   ALTER TABLE ONLY public."Hacks" DROP CONSTRAINT submission_fk;
       public          postgres    false    243    3376    239            A           2606    114851    Messages user2_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Messages"
    ADD CONSTRAINT user2_fk FOREIGN KEY ("receiverUsername") REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 =   ALTER TABLE ONLY public."Messages" DROP CONSTRAINT user2_fk;
       public          postgres    false    214    3338    215            B           2606    114856    Messages user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Messages"
    ADD CONSTRAINT user_fk FOREIGN KEY ("senderUsername") REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 <   ALTER TABLE ONLY public."Messages" DROP CONSTRAINT user_fk;
       public          postgres    false    214    3338    215            E           2606    114887    BlogEntry user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."BlogEntry"
    ADD CONSTRAINT user_fk FOREIGN KEY (username) REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 =   ALTER TABLE ONLY public."BlogEntry" DROP CONSTRAINT user_fk;
       public          postgres    false    3338    218    214            H           2606    114916    Comments user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Comments"
    ADD CONSTRAINT user_fk FOREIGN KEY (username) REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 <   ALTER TABLE ONLY public."Comments" DROP CONSTRAINT user_fk;
       public          postgres    false    220    214    3338            J           2606    114933    VotesOn user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."VotesOn"
    ADD CONSTRAINT user_fk FOREIGN KEY (username) REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 ;   ALTER TABLE ONLY public."VotesOn" DROP CONSTRAINT user_fk;
       public          postgres    false    214    221    3338            K           2606    114947    Announcement user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Announcement"
    ADD CONSTRAINT user_fk FOREIGN KEY (username) REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 @   ALTER TABLE ONLY public."Announcement" DROP CONSTRAINT user_fk;
       public          postgres    false    3338    214    223            L           2606    114959    Admin user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Admin"
    ADD CONSTRAINT user_fk FOREIGN KEY (username) REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 9   ALTER TABLE ONLY public."Admin" DROP CONSTRAINT user_fk;
       public          postgres    false    224    3338    214            N           2606    114983    ContestCreator user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."ContestCreator"
    ADD CONSTRAINT user_fk FOREIGN KEY ("creatorUsername") REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 B   ALTER TABLE ONLY public."ContestCreator" DROP CONSTRAINT user_fk;
       public          postgres    false    3338    214    226            O           2606    114995    Contestant user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Contestant"
    ADD CONSTRAINT user_fk FOREIGN KEY ("contestantUsername") REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 >   ALTER TABLE ONLY public."Contestant" DROP CONSTRAINT user_fk;
       public          postgres    false    214    3338    227            [           2606    115139    Submits user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Submits"
    ADD CONSTRAINT user_fk FOREIGN KEY (username) REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 ;   ALTER TABLE ONLY public."Submits" DROP CONSTRAINT user_fk;
       public          postgres    false    3338    214    240            `           2606    115194    Joins user_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public."Joins"
    ADD CONSTRAINT user_fk FOREIGN KEY (username) REFERENCES public."User"(username) ON UPDATE CASCADE ON DELETE CASCADE;
 9   ALTER TABLE ONLY public."Joins" DROP CONSTRAINT user_fk;
       public          postgres    false    3338    214    246               Y  x�}�MN�0�us��@��6U�uEH�BN=I-9v�h9=v��bAwQl}�7/��܃T
�-a˒��T@I�"-!�'k:�#����ძ� (3@���`z���VeO��}���ޚ�[BU_��z������;pk�)����]/��<�yZ�
H�R������Ѓ7 �Fen1,_�qڗ�ĥ�C�(������j��Q������~�z��[s��z6�ɠ43���Qj�6�B M��\�E�90t��r=�uI��w�q�����˵�1���2��Ѧd�%�΍��qg�2&��~�>3��I���j�y��ddc]޻�<owEQ|{��O         �   x�U��
�0D�ٯ���{UJ%x����bY�&e[��ۂ��4�7cn�~F'������e���$���O>Z��絆+3nhJ�i��ۣO
ˤl=�ZtS4\p��,�[n5�-�ύ#��n2��B���E
�n��[�Q/           x�}��n�0���SL �	PH���n��R���퍗L��cG�S����PT
W	ߙs�&�[瞤Rd���(��y�$�=���z.�V¢u#�v�l�,͆}�~��N�4姗]#δ6�^K����^*�+�NC�-5�RT�6e���^Q�?L�a����^��B�0!���W^�`i��Z:�w�c���q ����/�ÀS�7O���%u?���+
Ry�9���"~8*Fq���PM�0Sc������9{ٛ�~���p�prL�>y��^����;:���J
�"#ay����j��ӡ���A0/����F�"D��:N��"��X�~�>�^::[�!dX����L�NǿP�)0X}4���Kf�
�N@�-�6`ب�(�!㨘�P�l�Rlyu������Ű�_v��p!;����������=�ˣ�m}�{\�4�c~>���Ӊ�|�������LV�T2v�����(O���s6��(��4M'���^��]�R|         �   x�U��!D��
p��@-鿎 % �בw^�bR���a6�˪�DjT��F:&݊�$j�h��'ݒ�djVX�>pLn���I��yY�]�n���ZW���s�<��Qk���N���Fm��n:;�2;;�k�[:;�
;A��(��4.Y������Z�e�M>o�RT�      �     x�m�An� E��� `7v�kEi�TM"Pl�����MkCi���}f~�����^=wzV��L��q���i�1�G�?���Q�l?9�ꮓ�O���A����t�5��
�jZ�]��De�
��� l(_c`�a%TzP��\",�^~��ͩx�@<;�e�®�.�{p�`Ã���0g&����wH��=Ix�����&G��+�ػ�{�b<Z���(�Q�i��%Z�	(.�9�_0�m���E�Q�� �|'���         j  x�}W�n�6}���yk{�k��p�:vE� (P��J�����n��=CJZ�v��MQs9s���Qv[IM�����$�DA<8����F�[�Q�������_ΖN�5��復�g7F�Jy�Զd���ō��Wґ�lw#u+q[(�UY/�)D��2꿖�XY'��ך-��f��-�X�OsiĒ�9��dJ>�Q��X�AlU�$	�ޅN*�}�ٶ=�H%�w��}�W�Xn7��Y׀��!�3)#�ۨ�D�I:A?d�hd��H7�b�M�%�&�X,�M,���㓃������������ý����V!+��u��
y���V����[��t��.d[�p�����.%syPV��w�a
�p��eX�T��Ⓒ��o����~���l��:Zp<��x��@���pn�S���^��1H=ŷ'Sc}���+e8j~�B7I�dΡ�R[؏�.(Hx/P�FK���`J�6MSK8�y%�>�q%N��Z�K �l�b<�&��ۅ�T&w$='
�N|=�r��v��&S���B�cAA��)��4���gk��X�jX�ވi�=��I6�a�/��BV3�ǌ�T|=�����EQ�mO���Z�j�r�20��F1�D}<e��nP� �2m?Ҳ�!5!ws���<��]Jc=\gR�-��~�l�jD�q��������1D��S	����\��^��@׺.��uM`��[� �V�u:Tζe5A����h�yD��\D��%�2��+b
�p2Kh�18�#�Zyc	�ͺ��<<��4�,{��]��L��$q'�,+��pO%W}@4N�7�8���au�0�ڿ��$�f�	S����#r2�zBt�Q���V�w�l&ǒ9Y����� d�d��R�盃ew��w°�uh�c��aj9�(7�ڲU��ɓ^��f�N��]ۭ�a{2�t����k�-���}���ȅ�k<<Xv�R��<��s�8���T�<����I29(��0���ߏHxm}�#lz��1��w�I�5���}|��m��Y}T%�Q�j\g4�f�r��5;�X�x���>��]&�Qn'W�DzB�;�C\i�9.2|�ⓑs�Q����7"cIl��c-ui!&U�
�c�=��H�������
+�H��2TQW9�+늃�V�cw1=�\+G��Yq#��#đ����n�p=�5�}v�Օt�#i[��t�!��M��'�1U8�xc���Lb㒰�>W&)�<ŚTkdG�Py?�8\o�NʈJkĘpZ�,�r`}qP�4�"�8������I�lb\ȕ#H:$5B���MfP:���u+\�%�6-1�ǎ��� �r�湨����[v-}��u��>�/8z����kb�:_Z,��_�����_c]�q)�x^��4vKn���,K|.�5$��}��=X^ы�V���՚B2��N��$�[���Xv�%�������z���3���E�$%�0���m�v�73����}t���f��|��</[�ޙV�A�/~�D���.~�"�E�ĪW%;T<!gDEd��eF�?�%��I��d��l������3}}�&R�\6q��d;�Y�/�����p�_M����ʮW,���f�e��w��������ă/�         �  x��V]o�8}��¼�
L�y���i��>�4��$��ClG�S&�~�?�Kw_J!pϽ��ګ�����4df���l�������։b�^kb��m��Nhe7ĬfEC�0�JVS��f1�_ޯ�V���#[-?o���˛�l'�z&���c��R9�+CĤ64g;��p�Yݙ��A��'k��7$���
�c�W|[X7{�yC�����{#���{&;	W37̷`/D-�Z|D�Һd'm���*�.;�* �H�V�����Mz�0IOWG��57BU��e�&ء�=�b��G|?20�~�vc�8kā,#��ߤ	���9
�'Ӈk覔Bт}9AIW(�O
��.�`%��h#B��f@M0h�Pn�~����E��XϞ����&���e�K�kRJ�>1d�P#_;fa���!�}��,�I�5��?�1zy@]�5Fb�tW�a��ƛ��?����M&�S	�Ae����\P��k�����.�F�>��dr��S����:鲙�8;��2��U��F�EV���;7��%���/2��0C2���^q��.ZNԺ�~���%��a�;x��ؾspd,e��2��ɥ�쬻�&	�p�k��q�����B�:,�4
����Ĝ)P7F��8�J�u$0q���^��=?-�V;�e�v��B�7���Ӄ��׏}�L��J���E=��!,�ك�[6֕-�Xw��9X��S�`;���9�vu�A,Zru�P���Cj'޸��%�@�4���CC��*A�E�<5��(j?��α��i��I�����������b�F�F��	���%]�o��E������P���;*�O�R��8H)w���k��z��?����y�y?�����$��x�/�����&T��SX��Ԩw�[D�`s�-xT�W�!>%���M��=p[$
���)��t����h�V�>G[��λ��Ц[RP}O��\�y�A��
\��L��������Ov18�}����p	0h~�c�D�0Q���-$;#�6��bZ.��+���>�4z�ȏH�K�|�=^�	L���^wq�����(I	Ɔ��y��Y-GP�^gH!��4^�6@��|P\.�V18��aE��u�.LD�c�o.��@ɡ�U���m�����6�d���:";��N������������         H  x�m��N�0���S����i�����GӬ��b��o�@+�Ą��_����Ν�mAA!���
!I���Z���G!C�BJ�k�@���ɍ���Kd��s)�*R����2�r���s���
̆�rQ��H���b�L33c���5#�87w����qGU|]L�x���|��	EȆ^^�Bf�<���$�.�)�o׾��[���!N�P��^)����pn�CUzQU{�@�r5�d9M׾_��m�nLسL!�RK�0N��pV�2TmLU�$� U�]��1�v����<�`�MZ�(��J:�s"�Jl�4�ҡ��]�e�%�>         Z   x�ιD1B���cm���ￎ�M�`4�t�t�ˀ�HQL�|	c�Kl��.��hq��A�HQ��;�3�P��Ϧ͗|�s�����_)         /  x�u��n�0���S�> ��Mr����b+���]o��+�fmӴo�c�VB�fΜo��9x/��£S�k��5�U=��E�s��
�j�9=���桕0�:j�(s��E��9H�[R+��;{p�u��EV���ܷ��ؓa�$Q��7�(QL������u*���������*�V!�[�EV�_�GxP���ƖX9��y���7���gk���ua0*�%F�j�`��I�R9�n㋓�dj�v��;���^R��-s�A,gx�f���`�pR�v�,P�e���*����ǡ��*�Bl��'bw�^��T��Eg|��&Z��������jtq�������$��v�c����k,�j$j�5��%��C��|CdJZ�L^&�����}P�^�|���13������11����X���sI�Z����^[G͜��r��\�g���D��}h��~O�]��nLh�'���1��i\~I#�/I�'���H�� �"����V�gn��	-g/3��krb{��8|�9�T�C����0������"˲J1F#      	   �   x�%̱�0���aT,e������R���5�m��t;�r�o��;m+�v�.�r�J�r7��3��	��Aۧ*R&%��!v�CβLk�|@:3^@�{4k��3!��H�v�x.���{h�H�Pj�hX�o�F��I� |Z�4      
   e   x���H�IM11�43��J��O�H,JL�\���K����⌐" �d�z�g�B�|�ss+��+���Ғ�Ԃ�T�2����0�1'�-�(#���� &s$N         �   x���9�@Ek�)|� /�,s DOKc�HD��$0H$����x���w<���w $Z0T#SRJDA�QPW9Nl�߾�Զ�8�㇕\ظ��N�i��X�bl�Aٜ�9��nW��;�y_�6��[��&^u���i�*W2�;��q��dy�'�r!� 0mh         �   x�M�=�0E��~��5_vTD��Q��FR�H�o'u9ܳ��G��C;(��k-���(9�m���pNc�`M')��h:�+��ΰK~]CY`]�<�}��4�$�v���	���5�7��5�L�} |,:         �   x�e�;k�0 �����݄���K���3vQ��|T#���+�<�w�{�*J����3��S^�V��([��GL8����[��AhV�!Y'H��'I����(�V��^�������\$�������~�g�>�;�l�������I:���l��^��R�HpK���RqP��Z�gmoq�g��X&��AM��9T�ԫjV�[�~%�sN����͗         �   x�e�O� ����ѹ?G�b���ML��l`��堎x!������
�x�,���#:��H��]�C�6�u���6F8B	��V��l��-�8Yo�:�jp����A��}R]A�Ŏc<��v����K	ukXIB��U.[��k]e��e��/b���,��ufK(N<&���:� ��U`�      �     x�uUێ�0}_1��(�@^�U����ZiU�Re�gqbd;���;W���JΜ9sΰ��g����%�k~���Dk� �E(HxF���V{�9l�ic�AF��n�9�0f�8G=Զ��\J,�<I�l1�..5򴂋ҧ�8�* �.���(r����2��eT�z�
�D��U����RUX0�)p &E��[`�x:���~B)}�|�JK��N��3�����Z9D^A���^�nģ���Q�WuB8fVd�	**I���o`�J
uq�@rȶ�(s�{|���y��ڑ�^�š[�%'(ϐW`$���Z��P# }g����՝�����3�k&�!3�8K^y!r���� ��D��(͍ő��au�[��	�:��N8�F��;�Q�t_j�NH-�ʣp���ج���͌���&��ϥ�N��9���t9[[����e-t��!'V{�&pv���L�ڰux1[�m�Iڎ�s���"z��7���͜�����OC��.M~-ON��� ��k~��+��Nt�Lե���Ya���^�i��^E�+�&N�:�V�~���<�n�<�鷇pn�mf\�6�@s���[��MȜ�ז��w~���HI:�"�ٶ�H�,��@�1�k㿱��>;
K��BH]�e���/<���#��&M-V���0��iH�i�ǔ�zWH.ݔ�l�~��S�A�ω*eJ����o�Iｾ��m��u��Z�iR�	��E��e�k��οo�a~�����t4�Uc�         B   x��(-.����I-�4��@p��9��d�)�gnb�KjqIQ~%�o��7G�[��-���\1z\\\ 9�2!         @
  x��Y�n;}n}��X����K�\$�0� ��$^u�=$ێ��s�K/���$"�;��9UE������f�M�n����ʮ�P��1����ʉ�0���q��٦�e�&�TS�i�[q�xQ��fN�O����k��͘)sai?
��/����$�̎��h��g���X�+�.V"_g�R�4��}r�`r�֥?�uF�%���uhÔv��B++a/��ᅑ9V��.]U.�6��܊�l����h�]d7���`��f]y3��VN.�X�7t�G�V��$CXo	�~������[�a�EZ-m��f��	�w�]fW��6��삗ySr'��j��-�b�v�����Sb�%D:�>��#��F�<��b!s	�8�,:q�}ή�W���%/���γ�]t�Z��6+D�V{i`,xln/�+��W�쏪pas_^��5��\�<nUY��ګ����q��Qv��k̾*^[�$���!Xd�]�n�XrD�x�DkVh�g�;8��^uG��r�rW�l��e�H>��|�K�`%z�(�<8��t����Ǡ�5�Q���b��AZm:8.Ӏ<(� �s}q��c����}��xC�uggR�!m2:7ϥ��	~�}�G�.�Z��{@��`����q%���3C�%�A]j�yRs�-�[�j�v�Y�F�pY�	��dt
V~�Ӣ1@� �9���6�`s�<G�������YQ.H���� ���9��c�OvӔN֥��n#��Asr�S+�J���h����(�r|f�&L��>�����6��d@��?��
6u���&i� �#V�񰕆 y� �����/V�vZ�cUF�~ԆA�%���8�sm�3:e
��iǉG�t炝y���g��G���b
�7q���Z�|���*]ȅĐ�d�Ʀ���W:!L�x�FR�p�ǲ��� �����W�_A_5�T�P��y+A�Ԥ腃�@�;�A���ZK���BM։*n��nX��(��ؐ���6^δ	�8�q�)��a&B���Z7��.�'�e�^@eU�'����]T͵1"wma�d^��.^=���0K9O�MXˮ9�oz)���Z�-�cέ�h�vq��l|H��}�Ru�	>�6����H��k��CN@�-�%����7�+�I"2�7�T!��I{��r��Oھ�V��ݬ��^�n�:T�*����2P��[.��k\��.��ۥ����XB*��C�����H�0%�ޭ�Υ�I��}��v�UX߉�.ޔ��rŔ�z�x�k�(8�,�5،��s����hӚh]���H���@�p:j���d�)x���R9�9������0�Z��8}�LxM�t�� k��1�egJ��/��t���Mא`IaS ��f=~�U�x#��{�z���,L�e�l49n(ԑoj�M���c�W��5�턨�t���@�ܨ���<������~�E���-�>��	����<de ?�n\�;j�H��h����>ā-a��k�������b�������s�0�#�>�kA	���Wb�J7ʵyA-ZT(�,Z{z�5 lԕ/�?�/q���&���m�g;�ܻh	�����7JAH��FS*���Z���Z�27�Z/8�zm��N(�	���S��0 ۶���J��'Pt0$�� a{���8Ҫ���Կ��n�����N���)�6LN�>70J!�w!��5���\ :�J�sY�3���Х��1Z�}�Kj�y;'<���B�l~Ǟ��2f�=s<�R�}��)�hU��0��5�s�7Wۢ�M+t���+����л'���l�!�������7�v+;�k�ŏ���}�-Ńa��K�R+��ͮ�$�l|�L���*���.���{���,=����RQ=,�w�L�q�<��F�r�����D�CYr�M<3|M�>�ŧ'Q,�@FPU݋�l'�(�8�����-6@��(�J	C�9Ra}F"_9�-���l�F��ÉxP���AQ�5$A:C�Ar���#�^�=���4�׆6iق�:��,S�T��J�vA&6��9�p�K��z/���;�Ƴ\ʅ��`� �	V��Y(����2I>�Z�NC��#y'��yhm%��">��m!��4y��??��ԏ/3�Z��7��I�u�:D����\�Z�������ar�B����!l��f��l��G���-�B�~�d�Ǡ��G�� �?"��I?)�p�c*�v���4�띨�)���(3����o�%�	���$�6yu���%�ʟI���]-����l�⊲+'(�����i�q�8����i%��G� j����y+b0�+�6���ީ(y��h�~%�C.����>���h|0���8��Ko�.�d~�M�ʫ���/dx>M����͒h�U	6�) ��T�7���+8����Ԇ���MP2��e�{%��o���ڇLg�
�[�s�����A)��6��"Q�@pP/����ʹ�)��Z�R�k���6�S�����
$�	��^��l�+6�}��
�_Y�6�	>�u�a*�8������w��O         �   x�u�Mj1���)|��!���S��t#&��R����k�$ĉ����{Oވ�]��~��]���8'���A2�A8c*d#T��[��WfW����\�/���#��F�(TɣCK�0eQ;x�v+��ɯ������;�6�Lt|U9?�ߡ�z��&��K�t��"&G!����f2�7\�jqy���n�1;��"�#j�����C,o.مvs%���/Ƙ?����          �  x���;��@����*J"���}�mb,���1�R�{ԏ�w:�����wP�n=�O��vz�/��z�ݯ����=n���m��r�8�-�vo�m���|\��_����.��}�l����~\/�N˹Yk����nmh����}��4�|"����%��>�ѥ��Ϗ��q��0I��>?c���}�<?)���`01]�k��5�k�6l	�6Bl�26rl��lD�F���f�`Z�F�m�iI;��p�i�up�kM;��?7d�L��ךv���p����ך>u��t�l��54[}�kM�V��Z�A�c@hM�ChM�GhM���9[|�&ӑ�Y�LG!���LGGhM'_wF��t��Z�I�cFhM'���5�d:�5�d:�5�d:�5�d:��g��"�YH��LgGjM���5]��1!���L�Ԛ.2]Jk��tJk��t9Jk��tJk��t%Jk���*��t'��Q�12]#Jk���PZӝ'g��t���]k���_���R��           x���=O�0E��Wd����g����� ��D !��T �=��ɱ�w���=�v����]����IG����oV�m�~�CF��-��Вhft���1���q��߽����W������e��<������y$`L�T�`rZl�k�Nxd>�bs�}|��Z�b�!I�$T��j�P���ThxB�m#b�izHJ@�AP�A��^#1B
FL1"oC ��aY�5Z 1¢FX$\�����"�C�uH���7@�>ڜ�#N� >8��)�C|����=�a�����B��R|��#A�BГo�.K0zD_����q# @@�H��DD��>D���SL���""FDĈ�#��+1�A�	�$��HH�		6!��я���:�h���:��!$_&$`&��_P�f�}+�؅ը �0�
u�!�+{5�x�j��2�K[���g,ߏ��9c�U��-��0v-��=cyXU̝���:���V�̀�z�1���:fO�S7��~ >YuF           x�m�K��0�ϝ��w|���6G$-A��A����{�,��,\"}��~؎��y��8q��^�A�be0H�Q�4c2���a|Y���*�/p~��/���.�	���+��Yt=�[:�$Df/�	��$���	����i�񧄠�Buc�����魋��3l���H�y����F�UM�S����z�}z�����I
�Um���@䴆��FAjw�6�כ��(��N�M��n@1�V������w@�"4ܜ-vw�����h��𯵶X�:�h��p��X�j:��f�7�?�V	�����q�Ǜ�x��1�.����r�\��7�ȫL?R�@��ݛ@�U���@Zu0�<��Yo[Z�
ܽ�ȫ��op���y]ߐ�Hv@�+~a���eÈG��^k���x�O�~$V�u��<Px���k�ʺ������V�!�G�b$ �I��Hr֫��؞&�y�w!It<��p������XO`K���$��`/@
����R{�u�&�L           x�e��n�0����T$��9vw՞ZU��^(DK�6@%޾`	��%��x>�XS�q�} g.q�Skh����dno�KU}��k����������q�|kk�&�c�� �n-��-���?v͵�~&������s�X�`I+Ϧ��������K��8+�NN�&�rY��/���r��Ü�s����m��4��4
���LO
�Q��LJ֚4CrG½	��I�45�O
�^����dq��O)�!E&+�������� ��S��         �  x�u�]��0���O��*��s�y���`�=�~�2$F�H;mw��*^^��,(hw�n\�-*�-8�{K.+ZRRQ:���H�i�"q�B>Q�{�ţs�s�#���!o��Y��e<��۝O��rUg��ӭ(}6�)��"�j�j��G������d>	������Gw��������V���^5�_�ʠ�d׮^y��$��䶄�U��(�<��5D%�@Z�p��Ű��Æ�Ц��@���Y`S.��i���z�y�;�-W/�J��D/��͛ �d�qI��a���M�QJ�D�X,��-�^�wM_�U�3 :X����J�։+Z��X*6�yxAa�����w��#	�U�U�-����ZW,\���׺#k�����A�'OgX���t�wir��&�q|�������
��FY,��+��Y��^ �"�e>��df���pw0*�m��_f�����      �   �  x��W�rG}n~���\}��I�9��8�����jݍ6'"9�!���=CR�H�c\��e\��-�� �O���u��_	�1ژb%�ʩ*��k�:������s�6�������c�ɧx����xǙ��Zh�͙Tg��.��O4,h+�	����Q:ۦ$E
Er.��K�%J�C��zr��9�b炪a�)N�'��L�3�f��o9�hM�yS�i�`��Ķ ��F��d��l�k�8�L�Vr)��c�^\�W��q��L�ٛ�fs�-�<�����j�)����l1K �䙬��Hr�٤r M�s��ra�N�[�K�����pf��g���7ۡ�#�'O�0��djV*ND9S�ŵ�BѮT�x�9���J�%qII�����
4�}��/;{�l�� �	�j�F�5��H�d�m3�3��_�*���l'F!X�o.��%��~��}�=m�"�)?{C���o�њ�МN����R�d=�P+f�ESZ�*&�Jv��ˁ��J��O^a������v�o�;����V���<�l)�d��F�l\��T 0UY,���h�(��EJ-�_V4��hE]x���������ߋc�xU����\D��-:H�9���`]TV���R��n�*.🖨xsh��oïӬ��w,�i�:CfH�K��ؗ�J�+�h��������}"�!Cx��E�C�c��Ⱥ�]���1�� Z�ي��?)zW�^S݃wC���/]Y�K�b�m����7�\���t�VC�R+��t( �]S`��Y�UMY��U#KR=\���w�{^r���[Z�%�oS�bPoߜ'���G�L��,O��e V��:BbY�TC�G�P:���ݏ�����|�m�њ�WLq�aF:�a֌z�<�-$� k�Q)��)TA�X�����q~1E~�Z���M�)ӥ*���0>��t��+e�*�Q���@d�l���)�dT�)}p+0��ߠ���w���'O��n����C� 4H��F�#Tm�#e�a���aA{C� E�R&H��ɵ8!���U�F2���_�FL���:�q�B	��--����"��XAV7� �!B�"�I=�ǈ���#��xE_�z9���w�;<د$cz�Ā������ٙJ� I��5��%�}p����8|��"���t4~��|O��?��(0�*S���"U�6��Ƀ!�������2�")���rr+�O��Ҋ77�]?���I2�jr�3�n3X#�b��u� �f�=J�Aw�L�FZy���tt+N;�qZv?�� wb�0	��J����nEb��l�ԅ-��iH�;ٰ�b�c����P~��r�/�ʃ�"�.�=�����}2;�&j\p�U����t���?�x<�rY���RRb{��N����w����$~���}��7p��u˓�3g��h�ݭ����1�G������v�8.���>O��4���m�<�!V��a�f��f��|����6�ן�9�K�ӑ��g����b��F�w_�!L�U�7�_�j񮃦�t۲��R����h�tg*�^��>t�JT��J���.>]��X.�@�����~�qa�4��յ��
����{4a�㥾�{Z����!p�]��勤�xz^vk����/{��Q`K�5�m>���O��ָU�H��d��t�B�p�Ћ��7�wx~��4�]Y��z�VƝ�u���>�1	B�v�9Z�Z�t����8���}3Z%�ϪГ3��y�5R�ϋ�l�����         �   x�]��
�0Eי�$f��-�d���F�X������p.��tbr�c�N�?crX�����C���e������6��s�	�/.Y\r���0ᓘ�*1`v&�!���Q,���P�8;�׆׸,�h��b��۷��lXCC>�� �::Q�     