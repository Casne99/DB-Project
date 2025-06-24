--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

-- Started on 2025-06-24 21:13:51

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 6 (class 2615 OID 18809)
-- Name: develop; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA develop;


ALTER SCHEMA develop OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 19229)
-- Name: aggiorna_disponibilita_al_completamento(); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.aggiorna_disponibilita_al_completamento() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    r RECORD;
BEGIN
    IF NEW.completato AND NOT OLD.completato THEN
        FOR r IN
            SELECT prodotto, quantita
            FROM develop.prodotti_ordine
            WHERE ordine = NEW.id
        LOOP
            INSERT INTO develop.disponibilita (deposito, prodotto, quantita)
            VALUES (NEW.negozio, r.prodotto, r.quantita)
            ON CONFLICT (prodotto, deposito) DO UPDATE
            SET quantita = develop.disponibilita.quantita + EXCLUDED.quantita;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION develop.aggiorna_disponibilita_al_completamento() OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 19157)
-- Name: aggiorna_punti(); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.aggiorna_punti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Aggiunge un punto per ogni euro speso, solo se il cliente ha una tessera
    UPDATE develop.tessere
    SET punti = punti + FLOOR(NEW.totale)
    WHERE proprietario = NEW.cliente;

    RETURN NULL;
END;
$$;


ALTER FUNCTION develop.aggiorna_punti() OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 19225)
-- Name: check_login_exclusivity(); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.check_login_exclusivity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verifica se il login è già presente nell'altra tabella
    IF TG_TABLE_NAME = 'clienti' THEN
        IF EXISTS (SELECT 1 FROM develop.manager WHERE login = NEW.login) THEN
            RAISE EXCEPTION 'Login % già associato a un manager', NEW.login;
        END IF;
    ELSIF TG_TABLE_NAME = 'manager' THEN
        IF EXISTS (SELECT 1 FROM develop.clienti WHERE login = NEW.login) THEN
            RAISE EXCEPTION 'Login % già associato a un cliente', NEW.login;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION develop.check_login_exclusivity() OWNER TO postgres;

--
-- TOC entry 238 (class 1255 OID 19156)
-- Name: get_ordini_fornitore(character varying); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.get_ordini_fornitore(fornitore character varying) RETURNS SETOF integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY SELECT o.id
	FROM ordini AS o
	WHERE o.fornitore = fornitore;
END;
$$;


ALTER FUNCTION develop.get_ordini_fornitore(fornitore character varying) OWNER TO postgres;

--
-- TOC entry 237 (class 1255 OID 19155)
-- Name: get_tessere_negozio(character varying); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.get_tessere_negozio(negozio character varying) RETURNS TABLE(proprietario character)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY SELECT t.proprietario 
	FROM tessere AS t
	WHERE t.negozio_di_rilascio = $1;
END;
$_$;


ALTER FUNCTION develop.get_tessere_negozio(negozio character varying) OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 19224)
-- Name: inserisci_fattura_con_sconto_json(character, character varying, jsonb, numeric); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.inserisci_fattura_con_sconto_json(p_cliente character, p_deposito character varying, p_prodotti_json jsonb, p_sconto_percentuale numeric DEFAULT 0) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_punti_cliente INT := 0;
    v_punti_da_scalare INT := 0;
    v_sconto_applicato NUMERIC(5,2) := 0;
    v_id_fattura INT;
    prod_rec jsonb;
    v_prodotto varchar(7);
    v_quantita int;
    v_prezzo_unitario numeric(8,2);
    v_totale numeric := 0;
    v_soglia_punti INT;
    v_percentuale_sconto NUMERIC;
BEGIN
    -- Controllo punti solo se lo sconto è diverso da zero
    IF p_sconto_percentuale <> 0 THEN
        SELECT punti INTO v_punti_cliente
        FROM develop.tessere
        WHERE proprietario = p_cliente;

        IF v_punti_cliente IS NULL THEN
            RAISE EXCEPTION 'Tessera non trovata per il cliente %, impossibile applicare sconto', p_cliente;
        END IF;
    END IF;

    -- Calcolo totale basato sui prezzi nel deposito
    FOR prod_rec IN SELECT * FROM jsonb_array_elements(p_prodotti_json)
    LOOP
        v_prodotto := prod_rec ->> 'prodotto';
        v_quantita := (prod_rec ->> 'quantita')::int;

        SELECT c.prezzo INTO v_prezzo_unitario
        FROM develop.costi c
        JOIN develop.negozi n ON c.deposito = n.id
        WHERE c.deposito = p_deposito AND c.prodotto = v_prodotto AND n.attivo;

        IF v_prezzo_unitario IS NULL THEN
            RAISE EXCEPTION 'Prezzo non trovato per prodotto % nel deposito %', v_prodotto, p_deposito;
        END IF;

        v_totale := v_totale + (v_prezzo_unitario * v_quantita);
    END LOOP;

    -- Calcolo sconto
    IF p_sconto_percentuale = 0 THEN
        v_punti_da_scalare := 0;
        v_sconto_applicato := 0;
    ELSE
        SELECT
            CASE p_sconto_percentuale
                WHEN 5 THEN 100
                WHEN 15 THEN 200
                WHEN 30 THEN 300
                ELSE NULL
            END,
            p_sconto_percentuale
        INTO v_soglia_punti, v_percentuale_sconto;

        IF v_soglia_punti IS NULL THEN
            RAISE EXCEPTION 'Percentuale sconto non valida';
        END IF;

        IF v_punti_cliente < v_soglia_punti THEN
            RAISE EXCEPTION 'Punti insufficienti per applicare sconto %%%', v_percentuale_sconto;
        END IF;

        v_punti_da_scalare := v_soglia_punti;
        v_sconto_applicato := LEAST(v_totale * (v_percentuale_sconto / 100), 100);
    END IF;

    -- Inserimento fattura con negozio
    INSERT INTO develop.fatture (
        sconto_applicato,
        totale,
        data_acquisto,
        cliente,
        negozio
    )
    VALUES (
        v_sconto_applicato,
        v_totale - v_sconto_applicato,
        CURRENT_DATE,
        p_cliente,
        p_deposito
    )
    RETURNING id INTO v_id_fattura;

    -- Aggiorna prodotti_fattura e disponibilità per ogni prodotto
    FOR prod_rec IN SELECT * FROM jsonb_array_elements(p_prodotti_json)
    LOOP
        v_prodotto := prod_rec ->> 'prodotto';
        v_quantita := (prod_rec ->> 'quantita')::int;

        INSERT INTO develop.prodotti_fattura (prodotto, fattura, quantita)
        VALUES (v_prodotto, v_id_fattura, v_quantita);

        UPDATE develop.disponibilita
        SET quantita = quantita - v_quantita
        WHERE deposito = p_deposito
          AND prodotto = v_prodotto
          AND quantita >= v_quantita;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Disponibilità insufficiente per il prodotto % nel deposito %', v_prodotto, p_deposito;
        END IF;
    END LOOP;

    -- Aggiorna i punti tessera solo se lo sconto è stato applicato
    IF v_punti_da_scalare > 0 THEN
        UPDATE develop.tessere
        SET punti = punti - v_punti_da_scalare
        WHERE proprietario = p_cliente;
    END IF;

    RETURN v_id_fattura;
END;
$$;


ALTER FUNCTION develop.inserisci_fattura_con_sconto_json(p_cliente character, p_deposito character varying, p_prodotti_json jsonb, p_sconto_percentuale numeric) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 19170)
-- Name: inserisci_ordine_ottimizzato(text, json); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.inserisci_ordine_ottimizzato(negozio_id text, prodotti_json json) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    record JSON;
    prodotto_id TEXT;
    quantita_richiesta INTEGER;
    fornitore_id TEXT;
    ordine_id INTEGER;
BEGIN
    FOR record IN SELECT * FROM json_array_elements(prodotti_json) LOOP
        prodotto_id := record->>'prodotto';
        quantita_richiesta := (record->>'quantita')::INTEGER;

        -- Trova il fornitore più economico con disponibilità sufficiente per questo prodotto
        SELECT f.id INTO fornitore_id
        FROM develop.fornitori f
        JOIN develop.disponibilita d ON d.deposito = f.id AND d.prodotto = prodotto_id
        JOIN develop.costi pr ON pr.deposito = f.id AND pr.prodotto = prodotto_id
        WHERE d.quantita >= quantita_richiesta
        ORDER BY pr.prezzo ASC
        LIMIT 1;

        IF fornitore_id IS NULL THEN
            RAISE EXCEPTION 'Nessun fornitore ha disponibilità sufficiente per il prodotto %', prodotto_id;
        END IF;

        -- Inserisci l'ordine per questo singolo prodotto presso il miglior fornitore
        INSERT INTO develop.ordini (data_consegna, negozio, fornitore)
        VALUES (CURRENT_DATE, negozio_id, fornitore_id)
        RETURNING id INTO ordine_id;

        INSERT INTO develop.prodotti_ordine (ordine, prodotto, quantita)
        VALUES (ordine_id, prodotto_id, quantita_richiesta);

        UPDATE develop.disponibilita
        SET quantita = quantita - quantita_richiesta
        WHERE prodotto = prodotto_id AND deposito = fornitore_id;
    END LOOP;
END;
$$;


ALTER FUNCTION develop.inserisci_ordine_ottimizzato(negozio_id text, prodotti_json json) OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 19221)
-- Name: salva_storico_tessere(); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.salva_storico_tessere() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.attivo AND NOT NEW.attivo THEN
        INSERT INTO develop.storico_tessere (proprietario, punti, negozio_di_rilascio, data_richiesta)
        SELECT proprietario, punti, negozio_di_rilascio, data_richiesta
        FROM develop.tessere
        WHERE negozio_di_rilascio = OLD.id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION develop.salva_storico_tessere() OWNER TO postgres;

--
-- TOC entry 239 (class 1255 OID 19218)
-- Name: tr_storico_ordini_insert(); Type: FUNCTION; Schema: develop; Owner: postgres
--

CREATE FUNCTION develop.tr_storico_ordini_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO develop.storico_ordini (ordine_id, data_consegna, negozio_id, fornitore_id)
    VALUES (NEW.id, NEW.data_consegna, NEW.negozio, NEW.fornitore);

    RETURN NEW;
END;
$$;


ALTER FUNCTION develop.tr_storico_ordini_insert() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 218 (class 1259 OID 18834)
-- Name: clienti; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.clienti (
    nome character varying(100) NOT NULL,
    login character varying(60) NOT NULL,
    codice_fiscale character(16) NOT NULL,
    cognome character varying(100),
    genere character(1) NOT NULL,
    CONSTRAINT clienti_check CHECK ((char_length(codice_fiscale) = 16))
);


ALTER TABLE develop.clienti OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 18960)
-- Name: costi; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.costi (
    deposito character varying(7) NOT NULL,
    prodotto character varying(7) NOT NULL,
    prezzo numeric(8,2) DEFAULT 0 NOT NULL
);


ALTER TABLE develop.costi OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 18945)
-- Name: disponibilita; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.disponibilita (
    deposito character varying(7) NOT NULL,
    prodotto character varying(7) NOT NULL,
    quantita integer NOT NULL,
    CONSTRAINT disponibilita_check CHECK ((quantita >= 0))
);


ALTER TABLE develop.disponibilita OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 18910)
-- Name: fatture; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.fatture (
    sconto_applicato numeric(5,2) DEFAULT 0 NOT NULL,
    totale numeric(15,2) NOT NULL,
    data_acquisto date NOT NULL,
    id integer NOT NULL,
    cliente character(16) NOT NULL,
    negozio character varying(7) NOT NULL,
    CONSTRAINT fatture_check CHECK (((sconto_applicato >= (0)::numeric) AND (sconto_applicato <= (100)::numeric)))
);


ALTER TABLE develop.fatture OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 18909)
-- Name: fatture_id_seq; Type: SEQUENCE; Schema: develop; Owner: postgres
--

CREATE SEQUENCE develop.fatture_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE develop.fatture_id_seq OWNER TO postgres;

--
-- TOC entry 4958 (class 0 OID 0)
-- Dependencies: 223
-- Name: fatture_id_seq; Type: SEQUENCE OWNED BY; Schema: develop; Owner: postgres
--

ALTER SEQUENCE develop.fatture_id_seq OWNED BY develop.fatture.id;


--
-- TOC entry 222 (class 1259 OID 18880)
-- Name: fornitori; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.fornitori (
    id character varying(7) NOT NULL,
    partita_iva character(11) NOT NULL,
    CONSTRAINT fornitori_check CHECK ((char_length(partita_iva) = 11))
);


ALTER TABLE develop.fornitori OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 18815)
-- Name: manager; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.manager (
    id integer NOT NULL,
    nome character varying(100) NOT NULL,
    login character varying(60) NOT NULL,
    cognome character varying(100),
    genere character(1) NOT NULL
);


ALTER TABLE develop.manager OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 18860)
-- Name: negozi; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.negozi (
    id character varying(7) NOT NULL,
    orario_apertura time without time zone NOT NULL,
    orario_chiusura time without time zone NOT NULL,
    responsabile character varying(100) NOT NULL,
    manager integer NOT NULL,
    attivo boolean DEFAULT true NOT NULL
);


ALTER TABLE develop.negozi OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 19172)
-- Name: ordini; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.ordini (
    id integer NOT NULL,
    data_consegna date NOT NULL,
    negozio character varying(7) NOT NULL,
    fornitore character varying(7) NOT NULL,
    completato boolean DEFAULT false NOT NULL
);


ALTER TABLE develop.ordini OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 19171)
-- Name: ordini_id_seq; Type: SEQUENCE; Schema: develop; Owner: postgres
--

CREATE SEQUENCE develop.ordini_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE develop.ordini_id_seq OWNER TO postgres;

--
-- TOC entry 4964 (class 0 OID 0)
-- Dependencies: 232
-- Name: ordini_id_seq; Type: SEQUENCE OWNED BY; Schema: develop; Owner: postgres
--

ALTER SEQUENCE develop.ordini_id_seq OWNED BY develop.ordini.id;


--
-- TOC entry 225 (class 1259 OID 18923)
-- Name: prodotti; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.prodotti (
    id character varying(7) NOT NULL,
    nome character varying(100) NOT NULL,
    descrizione text NOT NULL
);


ALTER TABLE develop.prodotti OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 18976)
-- Name: prodotti_fattura; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.prodotti_fattura (
    prodotto character varying(7) NOT NULL,
    fattura integer NOT NULL,
    quantita integer NOT NULL
);


ALTER TABLE develop.prodotti_fattura OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 19195)
-- Name: prodotti_ordine; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.prodotti_ordine (
    quantita integer NOT NULL,
    ordine integer NOT NULL,
    prodotto character varying(7) NOT NULL
);


ALTER TABLE develop.prodotti_ordine OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 18855)
-- Name: punti_deposito; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.punti_deposito (
    id character varying(7) NOT NULL,
    indirizzo character varying(120) NOT NULL
);


ALTER TABLE develop.punti_deposito OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 19211)
-- Name: storico_ordini; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.storico_ordini (
    id integer NOT NULL,
    ordine_id integer NOT NULL,
    data_consegna date NOT NULL,
    negozio_id character varying(7) NOT NULL,
    fornitore_id character varying(7) NOT NULL,
    data_registrazione timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE develop.storico_ordini OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 19210)
-- Name: storico_ordini_id_seq; Type: SEQUENCE; Schema: develop; Owner: postgres
--

CREATE SEQUENCE develop.storico_ordini_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE develop.storico_ordini_id_seq OWNER TO postgres;

--
-- TOC entry 4971 (class 0 OID 0)
-- Dependencies: 235
-- Name: storico_ordini_id_seq; Type: SEQUENCE OWNED BY; Schema: develop; Owner: postgres
--

ALTER SEQUENCE develop.storico_ordini_id_seq OWNED BY develop.storico_ordini.id;


--
-- TOC entry 231 (class 1259 OID 19164)
-- Name: storico_tessere; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.storico_tessere (
    proprietario character(16) NOT NULL,
    punti integer NOT NULL,
    negozio_di_rilascio character varying(7) NOT NULL,
    data_richiesta date NOT NULL
);


ALTER TABLE develop.storico_tessere OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 18844)
-- Name: tessere; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.tessere (
    punti integer DEFAULT 0 NOT NULL,
    data_richiesta date DEFAULT CURRENT_DATE NOT NULL,
    proprietario character(16) NOT NULL,
    negozio_di_rilascio character varying(7) NOT NULL
);


ALTER TABLE develop.tessere OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 19151)
-- Name: tessere_oltre_300; Type: VIEW; Schema: develop; Owner: postgres
--

CREATE VIEW develop.tessere_oltre_300 AS
 SELECT punti,
    proprietario
   FROM develop.tessere
  WHERE (punti > 300);


ALTER VIEW develop.tessere_oltre_300 OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 18810)
-- Name: utenze; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.utenze (
    login character varying(60) NOT NULL,
    password character varying(60) NOT NULL
);


ALTER TABLE develop.utenze OWNER TO postgres;

--
-- TOC entry 4718 (class 2604 OID 18914)
-- Name: fatture id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture ALTER COLUMN id SET DEFAULT nextval('develop.fatture_id_seq'::regclass);


--
-- TOC entry 4720 (class 2604 OID 19175)
-- Name: ordini id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini ALTER COLUMN id SET DEFAULT nextval('develop.ordini_id_seq'::regclass);


--
-- TOC entry 4722 (class 2604 OID 19214)
-- Name: storico_ordini id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.storico_ordini ALTER COLUMN id SET DEFAULT nextval('develop.storico_ordini_id_seq'::regclass);


--
-- TOC entry 4931 (class 0 OID 18834)
-- Dependencies: 218
-- Data for Name: clienti; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.clienti (nome, login, codice_fiscale, cognome, genere) FROM stdin;
Frodo	frodo.baggins@contea.tdm	BGSFRD95C54F205Z	Baggins	M
Peregrino	peregrino.tuc@contea.tdm	TUCPRG20C08H507E	Tuc	M
Grima	grima.vermilinguo@rohan.tdm	GRMVRM90C08H501U	Vermilinguo	M
\.


--
-- TOC entry 4940 (class 0 OID 18960)
-- Dependencies: 227
-- Data for Name: costi; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.costi (deposito, prodotto, prezzo) FROM stdin;
PNT0003	PRD0001	50000.00
PNT0004	PRD0005	1500.00
PNT0005	PRD0022	1200.00
PNT0007	PRD0003	20.00
PNT0008	PRD0008	100.00
PNT0011	PRD0013	2000.00
PNT0012	PRD0007	25000.00
PNT0013	PRD0015	1800.00
PNT0016	PRD0006	450.00
PNT0019	PRD0024	300.00
PNT0003	PRD0010	900.00
PNT0004	PRD0002	7000.00
PNT0013	PRD0029	50.00
PNT0008	PRD0023	500.00
PNT0005	PRD0025	250.00
PNT0001	PRD0001	75000.00
PNT0002	PRD0003	30.00
PNT0006	PRD0011	1200.00
PNT0009	PRD0014	850.00
PNT0010	PRD0017	30000.00
PNT0014	PRD0010	1200.00
PNT0015	PRD0002	9000.00
PNT0017	PRD0027	150.00
PNT0018	PRD0018	4500.00
PNT0020	PRD0021	70.00
PNT0014	PRD0005	2100.00
PNT0020	PRD0029	65.00
PNT0017	PRD0023	650.00
PNT0002	PRD0025	352.00
PNT0004	PRD0017	70.00
PNT0004	PRD0009	70.00
PNT0001	PRD0003	18.50
PNT0001	PRD0008	22.00
PNT0001	PRD0005	12.75
PNT0001	PRD0006	17.30
PNT0002	PRD0005	13.20
PNT0002	PRD0007	25.00
PNT0002	PRD0010	20.80
PNT0002	PRD0001	16.90
PNT0006	PRD0014	28.90
PNT0006	PRD0017	30.00
PNT0006	PRD0003	19.10
PNT0006	PRD0008	22.30
PNT0009	PRD0018	33.60
PNT0009	PRD0010	20.50
PNT0009	PRD0005	14.00
PNT0009	PRD0006	17.80
PNT0010	PRD0008	23.40
PNT0010	PRD0011	20.70
PNT0010	PRD0003	18.00
PNT0010	PRD0001	15.50
PNT0011	PRD0001	16.20
PNT0014	PRD0003	19.80
PNT0014	PRD0006	17.60
PNT0014	PRD0001	15.70
PNT0015	PRD0006	18.30
PNT0015	PRD0014	28.00
PNT0015	PRD0003	20.10
PNT0015	PRD0008	22.70
PNT0017	PRD0018	34.20
PNT0017	PRD0005	13.80
PNT0017	PRD0001	15.80
PNT0018	PRD0021	36.40
PNT0018	PRD0008	23.10
PNT0018	PRD0003	18.60
PNT0018	PRD0010	21.10
PNT0020	PRD0006	17.10
PNT0020	PRD0018	32.70
PNT0020	PRD0005	13.50
PNT0009	PRD0022	38.80
PNT0009	PRD0017	30.50
PNT0009	PRD0009	15.20
\.


--
-- TOC entry 4939 (class 0 OID 18945)
-- Dependencies: 226
-- Data for Name: disponibilita; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.disponibilita (deposito, prodotto, quantita) FROM stdin;
PNT0001	PRD0003	20
PNT0001	PRD0008	15
PNT0001	PRD0005	10
PNT0002	PRD0005	10
PNT0002	PRD0007	7
PNT0002	PRD0010	6
PNT0002	PRD0001	2
PNT0006	PRD0011	12
PNT0006	PRD0014	10
PNT0006	PRD0017	8
PNT0006	PRD0003	14
PNT0006	PRD0008	9
PNT0009	PRD0014	10
PNT0009	PRD0018	12
PNT0009	PRD0010	7
PNT0009	PRD0005	5
PNT0009	PRD0006	6
PNT0010	PRD0008	12
PNT0010	PRD0011	9
PNT0010	PRD0003	10
PNT0010	PRD0001	3
PNT0004	PRD0005	80
PNT0007	PRD0003	200
PNT0008	PRD0008	90
PNT0011	PRD0013	60
PNT0012	PRD0007	70
PNT0013	PRD0015	40
PNT0016	PRD0006	150
PNT0019	PRD0024	95
PNT0014	PRD0010	15
PNT0003	PRD0010	70
PNT0004	PRD0002	120
PNT0013	PRD0029	80
PNT0008	PRD0023	60
PNT0005	PRD0025	50
PNT0011	PRD0001	1
PNT0014	PRD0005	7
PNT0014	PRD0003	11
PNT0014	PRD0006	8
PNT0014	PRD0001	2
PNT0015	PRD0002	9
PNT0015	PRD0006	7
PNT0015	PRD0014	8
PNT0015	PRD0003	10
PNT0015	PRD0008	5
PNT0017	PRD0027	6
PNT0017	PRD0023	7
PNT0017	PRD0018	8
PNT0017	PRD0005	9
PNT0017	PRD0001	3
PNT0018	PRD0018	15
PNT0018	PRD0021	10
PNT0018	PRD0008	9
PNT0018	PRD0003	12
PNT0018	PRD0010	7
PNT0020	PRD0021	8
PNT0020	PRD0029	10
PNT0020	PRD0006	7
PNT0020	PRD0018	6
PNT0020	PRD0005	5
PNT0005	PRD0022	46
PNT0009	PRD0022	4
PNT0009	PRD0017	3
PNT0009	PRD0009	1
PNT0001	PRD0001	0
PNT0010	PRD0017	10
PNT0002	PRD0003	14
PNT0004	PRD0017	28
PNT0004	PRD0009	68
PNT0001	PRD0006	7
\.


--
-- TOC entry 4937 (class 0 OID 18910)
-- Dependencies: 224
-- Data for Name: fatture; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.fatture (sconto_applicato, totale, data_acquisto, id, cliente, negozio) FROM stdin;
0.00	75000.00	2025-06-23	33	BGSFRD95C54F205Z	PNT0001
100.00	119900.00	2025-06-23	34	BGSFRD95C54F205Z	PNT0010
0.00	30.00	2025-06-24	35	TUCPRG20C08H507E	PNT0002
0.00	17.30	2025-06-24	36	GRMVRM90C08H501U	PNT0001
\.


--
-- TOC entry 4935 (class 0 OID 18880)
-- Dependencies: 222
-- Data for Name: fornitori; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.fornitori (id, partita_iva) FROM stdin;
PNT0003	00000000001
PNT0004	00000000002
PNT0005	00000000003
PNT0007	00000000004
PNT0008	00000000005
PNT0011	00000000006
PNT0012	00000000007
PNT0013	00000000008
PNT0016	00000000009
PNT0019	00000000010
\.


--
-- TOC entry 4930 (class 0 OID 18815)
-- Dependencies: 217
-- Data for Name: manager; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.manager (id, nome, login, cognome, genere) FROM stdin;
2	Aragorn	aragorn.elessar@gondor.tdm	Figlio di Arathorn	M
1	Gandalf	gandalf.grigio@valinor.ea	Il Grigio	M
\.


--
-- TOC entry 4934 (class 0 OID 18860)
-- Dependencies: 221
-- Data for Name: negozi; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.negozi (id, orario_apertura, orario_chiusura, responsabile, manager, attivo) FROM stdin;
PNT0001	09:00:00	18:00:00	Bilbo Baggins	2	t
PNT0002	08:30:00	17:30:00	Boromir di Gondor	2	t
PNT0006	10:00:00	19:00:00	Éowyn di Rohan	2	t
PNT0009	08:00:00	16:00:00	Théodred del Mark	2	t
PNT0010	09:00:00	17:00:00	Legolas di Bosco Atro	2	t
PNT0014	10:00:00	18:00:00	Bard l’Arciere	2	t
PNT0015	09:00:00	17:00:00	Nob del Pony Rampante	2	t
PNT0017	08:00:00	16:30:00	Imrahil di Dol Amroth	2	t
PNT0018	09:30:00	18:30:00	Gríma Vermilinguo	2	t
PNT0020	08:00:00	17:00:00	Tom Bombadil	2	t
\.


--
-- TOC entry 4944 (class 0 OID 19172)
-- Dependencies: 233
-- Data for Name: ordini; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.ordini (id, data_consegna, negozio, fornitore, completato) FROM stdin;
22	2025-06-23	PNT0009	PNT0005	t
23	2025-06-23	PNT0009	PNT0004	t
24	2025-06-23	PNT0009	PNT0004	t
25	2025-06-24	PNT0001	PNT0004	f
26	2025-06-24	PNT0001	PNT0004	f
27	2025-06-24	PNT0001	PNT0004	f
28	2025-06-24	PNT0020	PNT0004	f
\.


--
-- TOC entry 4938 (class 0 OID 18923)
-- Dependencies: 225
-- Data for Name: prodotti; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti (id, nome, descrizione) FROM stdin;
PRD0001	Anello del Potere	Un anello forgiato da Sauron per dominare tutti gli altri. Conferisce invisibilità e potere, ma corrompe chi lo possiede.
PRD0002	Spada Andúril	La spada riforgiata dai frammenti di Narsil, brandita da Aragorn. Simbolo del ritorno del re.
PRD0003	Manto Elfico	Un manto grigio-verde donato dagli Elfi di Lórien. Permette di confondersi con l’ambiente circostante.
PRD0004	Corno di Boromir	Corno di guerra portato da Boromir. Usato per richiedere aiuto in caso di emergenza.
PRD0005	Pane Lembas	Cibo elfico ad alta energia. Un solo morso può sostenere un viaggiatore per ore.
PRD0006	Bastone di Gandalf	Bastone magico di Gandalf, utilizzato per canalizzare il potere magico e fare luce nelle tenebre.
PRD0007	Palantír	Una delle Pietre Veggenti. Permette la comunicazione a distanza e la visione di eventi lontani nel tempo e nello spazio.
PRD0008	Fiala di Galadriel	Contenitore di cristallo con la luce della Stella di Eärendil. Illumina l’oscurità e respinge il male.
PRD0009	Ascia di Gimli	Ascia da battaglia nanica, robusta e affilata. Impiegata con maestria da Gimli, figlio di Glóin.
PRD0010	Pipa di Bilbo	Una semplice pipa in legno. Appartenuta a Bilbo Baggins, usata per fumare erba pipa della Contea.
PRD0011	Elmo di Théoden	Elmo dorato con criniera di cavallo, simbolo della regalità di Rohan. Indossato da Théoden in battaglia.
PRD0012	Scudo di Gondor	Scudo resistente con l’emblema dell’albero bianco. Usato dai soldati di Minas Tirith.
PRD0013	Lama di Morgul	Daga maledetta dei Nazgûl. Una ferita inferta da essa può corrompere l’anima.
PRD0014	Veste di Mithril	Corazza leggera e resistente fatta di mithril. Donata a Frodo da Bilbo, vale più dell’intera Contea.
PRD0015	Anello di Barahir	Antico anello elfico, simbolo della stirpe di Númenor. Portato da Aragorn.
PRD0016	Stella del Vespro	Gioiello donato da Arwen ad Aragorn. Simboleggia amore eterno e speranza.
PRD0017	Arco di Legolas	Arco lungo elfico di grande precisione, utilizzato con maestria da Legolas di Bosco Atro.
PRD0018	Libro Rosso dei Confini Occidentali	Cronaca scritta da Bilbo e Frodo, contenente la storia dello Hobbit e della Guerra dell’Anello.
PRD0019	Fiala di Athelas	Fiala contenente foglie di athelas, pianta curativa usata dai Re di Gondor.
PRD0020	Chiave di Erebor	Chiave antica che apre la porta segreta della Montagna Solitaria. Consegnata da Thorin a Bilbo.
PRD0021	Ciocca di Capelli di Galadriel	Tre fili dorati donati da Galadriel a Gimli come segno di stima e amicizia. Simbolo raro di benevolenza elfica verso i Nani.
PRD0022	Anello di Fuoco Narya	Uno dei Tre Anelli degli Elfi, portato da Gandalf. Accresce il coraggio e la forza interiore di chi lo circonda.
PRD0023	Collana Nauglamír	Antica collana dei Nani, incastonata con il Silmaril. Oggetto di grande bellezza e contesa nelle ere passate.
PRD0024	Coppa di Rohan	Coppa cerimoniale utilizzata nelle feste del regno di Rohan. Intarsiata con rune e cavalli alati.
PRD0025	Lanterna di Ithilien	Lanterna elfica che emana luce soffusa, usata dai rangers di Gondor durante le ricognizioni notturne.
PRD0026	Specchio di Galadriel	Bacile d’acqua incantato in cui si possono vedere visioni del passato, presente e possibili futuri.
PRD0027	Stendardo di Arwen	Stendardo nero con l’emblema reale di Elendil. Donato ad Aragorn da Arwen prima della sua incoronazione.
PRD0028	Anello d’Acqua Nenya	Anello elfico portato da Galadriel, fatto di mithril e diamante. Preserva la bellezza e la purezza dei luoghi.
PRD0029	Fionda di Sam	Semplice fionda utilizzata da Samvise Gamgee nei viaggi. Piccolo simbolo di coraggio hobbit.
PRD0030	Zaino di Frodo	Zaino robusto usato da Frodo durante il viaggio verso Mordor. Contiene provviste, mantello e il diario.
PRD0031	Vialetto della Contea	Pietra levigata proveniente da un vialetto di Hobbiton. Ricordo di casa per chi è lontano.
\.


--
-- TOC entry 4941 (class 0 OID 18976)
-- Dependencies: 228
-- Data for Name: prodotti_fattura; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti_fattura (prodotto, fattura, quantita) FROM stdin;
PRD0001	33	1
PRD0017	34	4
PRD0003	35	1
PRD0006	36	1
\.


--
-- TOC entry 4945 (class 0 OID 19195)
-- Dependencies: 234
-- Data for Name: prodotti_ordine; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti_ordine (quantita, ordine, prodotto) FROM stdin;
4	22	PRD0022
3	23	PRD0017
1	24	PRD0009
1	25	PRD0017
1	26	PRD0017
1	27	PRD0017
1	28	PRD0009
\.


--
-- TOC entry 4933 (class 0 OID 18855)
-- Dependencies: 220
-- Data for Name: punti_deposito; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.punti_deposito (id, indirizzo) FROM stdin;
PNT0001	Bottega dell’Anello, Hobbiton, Contea
PNT0002	Emporio di Minas Tirith, Prima Cerchia, Gondor
PNT0003	Magazzino dei Monti Brumosi, Passo Alto
PNT0004	Forgia di Erebor, Montagna Solitaria
PNT0005	Torre Bianca di Imladris, Gran Burrone
PNT0006	Dispensa del Fosso di Helm, Rohan
PNT0007	Emporio dei Grigi Porti, Lindon
PNT0008	Rifornimenti di Osgiliath, Riva Orientale, Gondor
PNT0009	Stanza delle Provviste, Edoras, Colle d’Oro
PNT0010	Bottega del Bosco Atro, Palazzo del Re, Thranduil
PNT0011	Magazzino del Nero Cancello, Mordor
PNT0012	Dispensa di Lórien, Caras Galadhon
PNT0013	Tesoreria di Khazad-dûm, Moria
PNT0014	Mercato del Lago, Città del Lago, Valle
PNT0015	Bottega di Bree, Accanto al Pony Rampante
PNT0016	Rivendita delle Colline di Ferro, Avamposto Nord
PNT0017	Stoccaggio di Dol Amroth, Porto Occidentale
PNT0018	Bottega di Isengard, Torre di Orthanc
PNT0019	Magazzino di Angmar, Rovine di Carn Dûm
PNT0020	Dispensa dei Tumuli, Piana di Andrath
\.


--
-- TOC entry 4947 (class 0 OID 19211)
-- Dependencies: 236
-- Data for Name: storico_ordini; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.storico_ordini (id, ordine_id, data_consegna, negozio_id, fornitore_id, data_registrazione) FROM stdin;
1	7	2025-06-21	01JTS10	01JTS14	2025-06-21 13:56:56.950574
3	11	2025-06-22	01JTS02	01JTS16	2025-06-22 15:13:02.521353
4	12	2025-06-22	01JTS02	01JTS16	2025-06-22 15:13:34.00533
5	13	2025-06-22	01JTS12	01JTS14	2025-06-22 15:18:59.606492
6	14	2025-06-22	01JTS03	01JTS14	2025-06-22 18:13:15.007607
7	15	2025-06-22	01JTS04	01JTS14	2025-06-22 18:40:36.505902
8	16	2025-06-22	01JTS04	01JTS14	2025-06-22 18:41:13.600936
14	22	2025-06-23	PNT0009	PNT0005	2025-06-23 22:36:51.738051
15	23	2025-06-23	PNT0009	PNT0004	2025-06-23 22:36:51.738051
16	24	2025-06-23	PNT0009	PNT0004	2025-06-23 22:36:51.738051
17	25	2025-06-24	PNT0001	PNT0004	2025-06-24 20:20:53.161114
18	26	2025-06-24	PNT0001	PNT0004	2025-06-24 20:21:00.808687
19	27	2025-06-24	PNT0001	PNT0004	2025-06-24 20:21:47.058629
20	28	2025-06-24	PNT0020	PNT0004	2025-06-24 20:45:46.067464
\.


--
-- TOC entry 4942 (class 0 OID 19164)
-- Dependencies: 231
-- Data for Name: storico_tessere; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.storico_tessere (proprietario, punti, negozio_di_rilascio, data_richiesta) FROM stdin;
SRABRS98C08F576W	3	01JTS02	2009-06-24
\.


--
-- TOC entry 4932 (class 0 OID 18844)
-- Dependencies: 219
-- Data for Name: tessere; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.tessere (punti, data_richiesta, proprietario, negozio_di_rilascio) FROM stdin;
194600	2025-06-23	BGSFRD95C54F205Z	PNT0001
\.


--
-- TOC entry 4929 (class 0 OID 18810)
-- Dependencies: 216
-- Data for Name: utenze; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.utenze (login, password) FROM stdin;
aragorn.elessar@gondor.tdm	$2b$12$XMvi6mtoDypc3NoFVfEjyevGaOtVpP5CEpQ6.6v4fRFQ.2BMQ3rCO
frodo.baggins@contea.tdm	$2y$10$2prECF6/cbFMga7Ff7KG8.o9jU8o8PwCN9HygDz.5WHFKwaVliFQm
peregrino.tuc@contea.tdm	$2y$10$xv9p2aug9yh22YaZeeo2n.cfpUGNxwTpVFmWspHR6Y4x9iHmSDMA.
grima.vermilinguo@rohan.tdm	$2y$10$9f3f2wuWI2wIXSh4seMMOeCdUMHhbbPk/iRUocFPk0zihFuy/pd96
gandalf.grigio@valinor.ea	$2b$12$THTJZAAnyM3nSB1keS8xW.Dcx54sIcBhCPyYV2OA4ARQe1fPajvDS
\.


--
-- TOC entry 4975 (class 0 OID 0)
-- Dependencies: 223
-- Name: fatture_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.fatture_id_seq', 36, true);


--
-- TOC entry 4976 (class 0 OID 0)
-- Dependencies: 232
-- Name: ordini_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.ordini_id_seq', 28, true);


--
-- TOC entry 4977 (class 0 OID 0)
-- Dependencies: 235
-- Name: storico_ordini_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.storico_ordini_id_seq', 20, true);


--
-- TOC entry 4733 (class 2606 OID 18838)
-- Name: clienti cliente_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.clienti
    ADD CONSTRAINT cliente_pk PRIMARY KEY (codice_fiscale);


--
-- TOC entry 4751 (class 2606 OID 19028)
-- Name: costi costi_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_pk PRIMARY KEY (deposito, prodotto);


--
-- TOC entry 4749 (class 2606 OID 19014)
-- Name: disponibilita disponibilita_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_pk PRIMARY KEY (prodotto, deposito);


--
-- TOC entry 4745 (class 2606 OID 18917)
-- Name: fatture fatture_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_pk PRIMARY KEY (id);


--
-- TOC entry 4741 (class 2606 OID 19053)
-- Name: fornitori fornitore_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitore_pk PRIMARY KEY (id);


--
-- TOC entry 4743 (class 2606 OID 18886)
-- Name: fornitori fornitore_unique; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitore_unique UNIQUE (partita_iva);


--
-- TOC entry 4739 (class 2606 OID 19065)
-- Name: negozi negozio_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozio_pk PRIMARY KEY (id);


--
-- TOC entry 4731 (class 2606 OID 18819)
-- Name: manager newtable_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT newtable_pk PRIMARY KEY (id);


--
-- TOC entry 4755 (class 2606 OID 19179)
-- Name: ordini ordini_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_pk PRIMARY KEY (id);


--
-- TOC entry 4753 (class 2606 OID 19100)
-- Name: prodotti_fattura prodotti_fattura_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_pk PRIMARY KEY (prodotto, fattura);


--
-- TOC entry 4757 (class 2606 OID 19199)
-- Name: prodotti_ordine prodotti_ordine_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_pk PRIMARY KEY (ordine, prodotto);


--
-- TOC entry 4747 (class 2606 OID 19092)
-- Name: prodotti prodotti_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti
    ADD CONSTRAINT prodotti_pk PRIMARY KEY (id);


--
-- TOC entry 4737 (class 2606 OID 19034)
-- Name: punti_deposito punto_deposito_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.punti_deposito
    ADD CONSTRAINT punto_deposito_pk PRIMARY KEY (id);


--
-- TOC entry 4759 (class 2606 OID 19217)
-- Name: storico_ordini storico_ordini_pkey; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.storico_ordini
    ADD CONSTRAINT storico_ordini_pkey PRIMARY KEY (id);


--
-- TOC entry 4735 (class 2606 OID 18849)
-- Name: tessere tessera_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessera_pk PRIMARY KEY (proprietario);


--
-- TOC entry 4729 (class 2606 OID 18814)
-- Name: utenze utenze_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.utenze
    ADD CONSTRAINT utenze_pk PRIMARY KEY (login);


--
-- TOC entry 4780 (class 2620 OID 19226)
-- Name: clienti check_login_exclusive_clienti; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER check_login_exclusive_clienti BEFORE INSERT OR UPDATE ON develop.clienti FOR EACH ROW EXECUTE FUNCTION develop.check_login_exclusivity();


--
-- TOC entry 4779 (class 2620 OID 19227)
-- Name: manager check_login_exclusive_manager; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER check_login_exclusive_manager BEFORE INSERT OR UPDATE ON develop.manager FOR EACH ROW EXECUTE FUNCTION develop.check_login_exclusivity();


--
-- TOC entry 4783 (class 2620 OID 19230)
-- Name: ordini trg_completamento_ordine; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER trg_completamento_ordine AFTER UPDATE OF completato ON develop.ordini FOR EACH ROW EXECUTE FUNCTION develop.aggiorna_disponibilita_al_completamento();


--
-- TOC entry 4784 (class 2620 OID 19243)
-- Name: ordini trg_storico_ordini; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER trg_storico_ordini AFTER INSERT ON develop.ordini FOR EACH ROW EXECUTE FUNCTION develop.tr_storico_ordini_insert();


--
-- TOC entry 4782 (class 2620 OID 19158)
-- Name: fatture trigger_aggiorna_punti; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER trigger_aggiorna_punti AFTER INSERT ON develop.fatture FOR EACH ROW EXECUTE FUNCTION develop.aggiorna_punti();


--
-- TOC entry 4781 (class 2620 OID 19222)
-- Name: negozi trigger_salva_storico_tessere; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER trigger_salva_storico_tessere BEFORE UPDATE OF attivo ON develop.negozi FOR EACH ROW EXECUTE FUNCTION develop.salva_storico_tessere();


--
-- TOC entry 4761 (class 2606 OID 18839)
-- Name: clienti cliente_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.clienti
    ADD CONSTRAINT cliente_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4771 (class 2606 OID 19146)
-- Name: costi costi_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4772 (class 2606 OID 19141)
-- Name: costi costi_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_punti_deposito_fk FOREIGN KEY (deposito) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4769 (class 2606 OID 19136)
-- Name: disponibilita disponibilita_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4770 (class 2606 OID 19131)
-- Name: disponibilita disponibilita_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_punti_deposito_fk FOREIGN KEY (deposito) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4767 (class 2606 OID 18918)
-- Name: fatture fatture_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_cliente_fk FOREIGN KEY (cliente) REFERENCES develop.clienti(codice_fiscale);


--
-- TOC entry 4768 (class 2606 OID 19254)
-- Name: fatture fatture_negozi_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_negozi_fk FOREIGN KEY (negozio) REFERENCES develop.negozi(id);


--
-- TOC entry 4766 (class 2606 OID 19059)
-- Name: fornitori fornitori_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitori_punti_deposito_fk FOREIGN KEY (id) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4764 (class 2606 OID 19070)
-- Name: negozi negozi_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozi_punti_deposito_fk FOREIGN KEY (id) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4765 (class 2606 OID 18875)
-- Name: negozi negozio_manager_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozio_manager_fk FOREIGN KEY (manager) REFERENCES develop.manager(id);


--
-- TOC entry 4775 (class 2606 OID 19180)
-- Name: ordini ordini_fornitori_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_fornitori_fk FOREIGN KEY (fornitore) REFERENCES develop.fornitori(id);


--
-- TOC entry 4776 (class 2606 OID 19185)
-- Name: ordini ordini_negozi_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_negozi_fk FOREIGN KEY (negozio) REFERENCES develop.negozi(id);


--
-- TOC entry 4773 (class 2606 OID 18981)
-- Name: prodotti_fattura prodotti_fattura_fatture_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_fatture_fk FOREIGN KEY (fattura) REFERENCES develop.fatture(id);


--
-- TOC entry 4774 (class 2606 OID 19105)
-- Name: prodotti_fattura prodotti_fattura_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id) ON UPDATE CASCADE;


--
-- TOC entry 4777 (class 2606 OID 19200)
-- Name: prodotti_ordine prodotti_ordine_ordini_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_ordini_fk FOREIGN KEY (ordine) REFERENCES develop.ordini(id);


--
-- TOC entry 4778 (class 2606 OID 19205)
-- Name: prodotti_ordine prodotti_ordine_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4762 (class 2606 OID 19236)
-- Name: tessere tessera_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessera_cliente_fk FOREIGN KEY (proprietario) REFERENCES develop.clienti(codice_fiscale) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4763 (class 2606 OID 19231)
-- Name: tessere tessere_negozi_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessere_negozi_fk FOREIGN KEY (negozio_di_rilascio) REFERENCES develop.negozi(id);


--
-- TOC entry 4760 (class 2606 OID 18820)
-- Name: manager utenze_manager_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT utenze_manager_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4953 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA develop; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA develop TO webapp;


--
-- TOC entry 4954 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE clienti; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE develop.clienti TO webapp;


--
-- TOC entry 4955 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE costi; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE develop.costi TO webapp;


--
-- TOC entry 4956 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE disponibilita; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,UPDATE ON TABLE develop.disponibilita TO webapp;


--
-- TOC entry 4957 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE fatture; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.fatture TO webapp;


--
-- TOC entry 4959 (class 0 OID 0)
-- Dependencies: 223
-- Name: SEQUENCE fatture_id_seq; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE develop.fatture_id_seq TO webapp;


--
-- TOC entry 4960 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE fornitori; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.fornitori TO webapp;


--
-- TOC entry 4961 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE manager; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT ON TABLE develop.manager TO webapp;


--
-- TOC entry 4962 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE negozi; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.negozi TO webapp;


--
-- TOC entry 4963 (class 0 OID 0)
-- Dependencies: 233
-- Name: TABLE ordini; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.ordini TO webapp;


--
-- TOC entry 4965 (class 0 OID 0)
-- Dependencies: 232
-- Name: SEQUENCE ordini_id_seq; Type: ACL; Schema: develop; Owner: postgres
--

GRANT USAGE ON SEQUENCE develop.ordini_id_seq TO webapp;


--
-- TOC entry 4966 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE prodotti; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.prodotti TO webapp;


--
-- TOC entry 4967 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE prodotti_fattura; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.prodotti_fattura TO webapp;


--
-- TOC entry 4968 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE prodotti_ordine; Type: ACL; Schema: develop; Owner: postgres
--

GRANT INSERT ON TABLE develop.prodotti_ordine TO webapp;


--
-- TOC entry 4969 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE punti_deposito; Type: ACL; Schema: develop; Owner: postgres
--

GRANT INSERT ON TABLE develop.punti_deposito TO webapp;


--
-- TOC entry 4970 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE storico_ordini; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.storico_ordini TO webapp;


--
-- TOC entry 4972 (class 0 OID 0)
-- Dependencies: 235
-- Name: SEQUENCE storico_ordini_id_seq; Type: ACL; Schema: develop; Owner: postgres
--

GRANT USAGE ON SEQUENCE develop.storico_ordini_id_seq TO webapp;


--
-- TOC entry 4973 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE tessere; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE develop.tessere TO webapp;


--
-- TOC entry 4974 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE utenze; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE develop.utenze TO webapp;


-- Completed on 2025-06-24 21:13:51

--
-- PostgreSQL database dump complete
--

