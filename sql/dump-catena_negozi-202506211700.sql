--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

-- Started on 2025-06-21 17:00:51

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
-- TOC entry 255 (class 1255 OID 19224)
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

    -- Inserimento fattura con totale netto
    INSERT INTO develop.fatture (sconto_applicato, totale, data_acquisto, cliente)
    VALUES (v_sconto_applicato, v_totale - v_sconto_applicato, CURRENT_DATE, p_cliente)
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
-- TOC entry 254 (class 1255 OID 19170)
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
    IF OLD.attivo = true AND NEW.attivo = false THEN
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
    genere character(1) NOT NULL
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
-- TOC entry 4945 (class 0 OID 0)
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
    partita_iva character(11) NOT NULL
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
    fornitore character varying(7) NOT NULL
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
-- TOC entry 4947 (class 0 OID 0)
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
    ordine_id integer,
    data_consegna date,
    negozio_id character varying(7),
    fornitore_id character varying(7),
    data_registrazione timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
-- TOC entry 4948 (class 0 OID 0)
-- Dependencies: 235
-- Name: storico_ordini_id_seq; Type: SEQUENCE OWNED BY; Schema: develop; Owner: postgres
--

ALTER SEQUENCE develop.storico_ordini_id_seq OWNED BY develop.storico_ordini.id;


--
-- TOC entry 231 (class 1259 OID 19164)
-- Name: storico_tessere; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.storico_tessere (
    proprietario character(16),
    punti integer,
    negozio_di_rilascio character varying(7),
    data_richiesta date
);


ALTER TABLE develop.storico_tessere OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 18844)
-- Name: tessere; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.tessere (
    punti integer DEFAULT 0 NOT NULL,
    data_richiesta date NOT NULL,
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
-- TOC entry 4715 (class 2604 OID 18914)
-- Name: fatture id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture ALTER COLUMN id SET DEFAULT nextval('develop.fatture_id_seq'::regclass);


--
-- TOC entry 4717 (class 2604 OID 19175)
-- Name: ordini id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini ALTER COLUMN id SET DEFAULT nextval('develop.ordini_id_seq'::regclass);


--
-- TOC entry 4718 (class 2604 OID 19214)
-- Name: storico_ordini id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.storico_ordini ALTER COLUMN id SET DEFAULT nextval('develop.storico_ordini_id_seq'::regclass);


--
-- TOC entry 4921 (class 0 OID 18834)
-- Dependencies: 218
-- Data for Name: clienti; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.clienti (nome, login, codice_fiscale, cognome, genere) FROM stdin;
Claudio	claudio.gennari@gmail.com	CLDGNR99C08F576W	Gennari	M
Sara	sara.brusaferri@gmail.com	SRABRS98C08F576W	Brusaferri	F
Sara	sara.gianni@gmail.com	GNNSRA95C55F205Z	Gianni	F
Riccardo	riccardo.nuzzo@gmail.com	NZZRCR90C08H501U	Nuzzo	M
\.


--
-- TOC entry 4930 (class 0 OID 18960)
-- Dependencies: 227
-- Data for Name: costi; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.costi (deposito, prodotto, prezzo) FROM stdin;
01JTS01	P00001	1.20
01JTS01	P00002	1.50
01JTS02	P00003	0.90
01JTS04	P00005	1.10
01JTS05	P00001	1.25
01JTS06	P00002	1.45
01JTS14	P00001	1.20
01JTS15	P00002	1.50
01JTS16	P00003	0.90
01JTS17	P00004	6.50
01JTS18	P00005	1.10
01JTS19	P00001	1.25
01JTS20	P00002	1.45
01JTS03	P00004	4.00
01JTS14	P00004	4.10
\.


--
-- TOC entry 4929 (class 0 OID 18945)
-- Dependencies: 226
-- Data for Name: disponibilita; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.disponibilita (deposito, prodotto, quantita) FROM stdin;
01JTS01	P00001	120
01JTS01	P00002	80
01JTS02	P00003	200
01JTS04	P00005	100
01JTS05	P00001	60
01JTS06	P00002	90
01JTS15	P00002	80
01JTS16	P00003	200
01JTS17	P00004	150
01JTS18	P00005	100
01JTS19	P00001	60
01JTS20	P00002	20
01JTS14	P00001	13
01JTS14	P00004	80
01JTS03	P00004	87
\.


--
-- TOC entry 4927 (class 0 OID 18910)
-- Dependencies: 224
-- Data for Name: fatture; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.fatture (sconto_applicato, totale, data_acquisto, id, cliente) FROM stdin;
0.00	20.00	2025-06-21	3	NZZRCR90C08H501U
0.00	32.00	2025-06-21	4	NZZRCR90C08H501U
0.00	120.00	2025-06-21	5	NZZRCR90C08H501U
0.00	40.00	2025-06-21	6	SRABRS98C08F576W
0.00	40.00	2025-06-21	7	SRABRS98C08F576W
\.


--
-- TOC entry 4925 (class 0 OID 18880)
-- Dependencies: 222
-- Data for Name: fornitori; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.fornitori (id, partita_iva) FROM stdin;
01JTS25	11223344556
01JTS14	01234567890
01JTS15	09876543210
01JTS16	12345678901
01JTS17	23456789012
01JTS18	34567890123
01JTS19	45678901234
01JTS20	56789012345
01JTS21	67890123456
01JTS22	78901234567
01JTS23	89012345678
01JTS24	90123456789
\.


--
-- TOC entry 4920 (class 0 OID 18815)
-- Dependencies: 217
-- Data for Name: manager; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.manager (id, nome, login, cognome, genere) FROM stdin;
1	Mario	mario.brambilla@protonmail.com	Brambilla	M
\.


--
-- TOC entry 4924 (class 0 OID 18860)
-- Dependencies: 221
-- Data for Name: negozi; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.negozi (id, orario_apertura, orario_chiusura, responsabile, manager, attivo) FROM stdin;
01JTS13	09:00:00	18:00:00	Davide Fontana	1	t
01JTS03	09:00:00	18:00:00	Giovanni Verdi	1	t
01JTS04	08:00:00	17:00:00	Chiara Neri	1	t
01JTS05	07:30:00	16:30:00	Federico Gallo	1	t
01JTS06	08:00:00	17:00:00	Elena Russo	1	t
01JTS07	09:00:00	18:00:00	Luca Conti	1	t
01JTS08	08:30:00	17:30:00	Sara Costa	1	t
01JTS09	08:00:00	16:00:00	Alessandro Greco	1	t
01JTS10	07:00:00	15:00:00	Martina De Luca	1	t
01JTS11	08:00:00	17:00:00	Giorgio Rinaldi	1	t
01JTS12	08:00:00	17:00:00	Francesca Moretti	1	t
01JTS02	08:30:00	17:30:00	Luisa Bianchi	1	t
\.


--
-- TOC entry 4934 (class 0 OID 19172)
-- Dependencies: 233
-- Data for Name: ordini; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.ordini (id, data_consegna, negozio, fornitore) FROM stdin;
1	2025-06-21	01JTS02	01JTS14
2	2025-06-21	01JTS02	01JTS14
3	2025-06-21	01JTS02	01JTS14
4	2025-06-21	01JTS02	01JTS14
5	2025-06-21	01JTS10	01JTS14
6	2025-06-21	01JTS10	01JTS14
7	2025-06-21	01JTS10	01JTS14
\.


--
-- TOC entry 4928 (class 0 OID 18923)
-- Dependencies: 225
-- Data for Name: prodotti; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti (id, nome, descrizione) FROM stdin;
P00001	Latte Intero	Latte fresco intero da 1 litro
P00002	Pane Integrale	Pane integrale a fette, confezione da 500g
P00003	Pasta Penne	Pasta di semola di grano duro, penne rigate, 500g
P00004	Olio Extra Vergine	Olio extra vergine di oliva, bottiglia da 1 litro
P00005	Pomodori Pelati	Pomodori pelati in scatola, 400g
\.


--
-- TOC entry 4931 (class 0 OID 18976)
-- Dependencies: 228
-- Data for Name: prodotti_fattura; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti_fattura (prodotto, fattura, quantita) FROM stdin;
P00004	3	5
P00004	4	8
P00004	5	30
P00004	6	10
P00004	7	10
\.


--
-- TOC entry 4935 (class 0 OID 19195)
-- Dependencies: 234
-- Data for Name: prodotti_ordine; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti_ordine (quantita, ordine, prodotto) FROM stdin;
50	1	P00001
7	2	P00001
7	3	P00004
7	4	P00004
2	5	P00004
2	6	P00004
2	7	P00004
\.


--
-- TOC entry 4923 (class 0 OID 18855)
-- Dependencies: 220
-- Data for Name: punti_deposito; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.punti_deposito (id, indirizzo) FROM stdin;
01JTS21	7 Wayridge Place
01JTS01	28964 Ridgeview Park
01JTS02	136 Service Junction
01JTS03	05354 Raven Parkway
01JTS04	42 Village Green Trail
01JTS05	753 Kings Street
01JTS06	0403 Garrison Crossing
01JTS07	230 Independence Terrace
01JTS08	16247 Northview Way
01JTS09	4201 Derek Junction
01JTS10	3 Annamark Pass
01JTS11	833 Huxley Drive
01JTS12	44 Scofield Place
01JTS13	9 Bartillon Point
01JTS14	81 Northport Place
01JTS15	39653 Moose Drive
01JTS16	5585 Mosinee Road
01JTS17	3010 Quincy Center
01JTS18	5 Golden Leaf Plaza
01JTS19	7 Clarendon Place
01JTS20	718 Scofield Drive
01JTS22	247 Green Ridge Point
01JTS23	04276 Grayhawk Junction
01JTS24	494 Westport Point
01JTS25	019 Hagan Street
\.


--
-- TOC entry 4937 (class 0 OID 19211)
-- Dependencies: 236
-- Data for Name: storico_ordini; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.storico_ordini (id, ordine_id, data_consegna, negozio_id, fornitore_id, data_registrazione) FROM stdin;
1	7	2025-06-21	01JTS10	01JTS14	2025-06-21 13:56:56.950574
\.


--
-- TOC entry 4932 (class 0 OID 19164)
-- Dependencies: 231
-- Data for Name: storico_tessere; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.storico_tessere (proprietario, punti, negozio_di_rilascio, data_richiesta) FROM stdin;
SRABRS98C08F576W	3	01JTS02	2009-06-24
\.


--
-- TOC entry 4922 (class 0 OID 18844)
-- Dependencies: 219
-- Data for Name: tessere; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.tessere (punti, data_richiesta, proprietario, negozio_di_rilascio) FROM stdin;
83	2009-06-24	SRABRS98C08F576W	01JTS02
\.


--
-- TOC entry 4919 (class 0 OID 18810)
-- Dependencies: 216
-- Data for Name: utenze; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.utenze (login, password) FROM stdin;
claudio.gennari@gmail.com	$2b$12$VC3rIRGLGphbSasHU0AZEOU3VnZB3mTt2xKRDIeQwVwXy/.wCfN6C
sara.gianni@gmail.com	$2y$10$saJehlmBIZDwWkhIM4ojoOTdTnxhxiVggbKkW2dkcNtNx3siW0r9e
mario.brambilla@protonmail.com	$2y$10$/llMa72HAQBNJoKLiPlssuSVxcMgSBqegAPCuXXdOdnLxYdRH.4km
sara.brusaferri@gmail.com	$2y$10$ym/fBAeUvT5PXDBX.8pdR.8vdKfZ6DDzYS9NoOjxzCvqI595k2KyW
riccardo.nuzzo@gmail.com	$2y$10$bNqkjfJHRiELNjqckhKL9ee1p0ZV9M7Jae1SHnMQfOk7CWoW4M3X6
\.


--
-- TOC entry 4951 (class 0 OID 0)
-- Dependencies: 223
-- Name: fatture_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.fatture_id_seq', 7, true);


--
-- TOC entry 4952 (class 0 OID 0)
-- Dependencies: 232
-- Name: ordini_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.ordini_id_seq', 7, true);


--
-- TOC entry 4953 (class 0 OID 0)
-- Dependencies: 235
-- Name: storico_ordini_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.storico_ordini_id_seq', 1, true);


--
-- TOC entry 4727 (class 2606 OID 18838)
-- Name: clienti cliente_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.clienti
    ADD CONSTRAINT cliente_pk PRIMARY KEY (codice_fiscale);


--
-- TOC entry 4745 (class 2606 OID 19028)
-- Name: costi costi_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_pk PRIMARY KEY (deposito, prodotto);


--
-- TOC entry 4743 (class 2606 OID 19014)
-- Name: disponibilita disponibilita_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_pk PRIMARY KEY (prodotto, deposito);


--
-- TOC entry 4739 (class 2606 OID 18917)
-- Name: fatture fatture_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_pk PRIMARY KEY (id);


--
-- TOC entry 4735 (class 2606 OID 19053)
-- Name: fornitori fornitore_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitore_pk PRIMARY KEY (id);


--
-- TOC entry 4737 (class 2606 OID 18886)
-- Name: fornitori fornitore_unique; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitore_unique UNIQUE (partita_iva);


--
-- TOC entry 4733 (class 2606 OID 19065)
-- Name: negozi negozio_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozio_pk PRIMARY KEY (id);


--
-- TOC entry 4725 (class 2606 OID 18819)
-- Name: manager newtable_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT newtable_pk PRIMARY KEY (id);


--
-- TOC entry 4749 (class 2606 OID 19179)
-- Name: ordini ordini_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_pk PRIMARY KEY (id);


--
-- TOC entry 4747 (class 2606 OID 19100)
-- Name: prodotti_fattura prodotti_fattura_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_pk PRIMARY KEY (prodotto, fattura);


--
-- TOC entry 4751 (class 2606 OID 19199)
-- Name: prodotti_ordine prodotti_ordine_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_pk PRIMARY KEY (ordine, prodotto);


--
-- TOC entry 4741 (class 2606 OID 19092)
-- Name: prodotti prodotti_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti
    ADD CONSTRAINT prodotti_pk PRIMARY KEY (id);


--
-- TOC entry 4731 (class 2606 OID 19034)
-- Name: punti_deposito punto_deposito_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.punti_deposito
    ADD CONSTRAINT punto_deposito_pk PRIMARY KEY (id);


--
-- TOC entry 4753 (class 2606 OID 19217)
-- Name: storico_ordini storico_ordini_pkey; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.storico_ordini
    ADD CONSTRAINT storico_ordini_pkey PRIMARY KEY (id);


--
-- TOC entry 4729 (class 2606 OID 18849)
-- Name: tessere tessera_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessera_pk PRIMARY KEY (proprietario);


--
-- TOC entry 4723 (class 2606 OID 18814)
-- Name: utenze utenze_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.utenze
    ADD CONSTRAINT utenze_pk PRIMARY KEY (login);


--
-- TOC entry 4774 (class 2620 OID 19219)
-- Name: ordini trg_storico_ordini; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER trg_storico_ordini AFTER INSERT ON develop.ordini FOR EACH ROW EXECUTE FUNCTION develop.tr_storico_ordini_insert();


--
-- TOC entry 4773 (class 2620 OID 19158)
-- Name: fatture trigger_aggiorna_punti; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER trigger_aggiorna_punti AFTER INSERT ON develop.fatture FOR EACH ROW EXECUTE FUNCTION develop.aggiorna_punti();


--
-- TOC entry 4772 (class 2620 OID 19222)
-- Name: negozi trigger_salva_storico_tessere; Type: TRIGGER; Schema: develop; Owner: postgres
--

CREATE TRIGGER trigger_salva_storico_tessere BEFORE UPDATE OF attivo ON develop.negozi FOR EACH ROW EXECUTE FUNCTION develop.salva_storico_tessere();


--
-- TOC entry 4755 (class 2606 OID 18839)
-- Name: clienti cliente_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.clienti
    ADD CONSTRAINT cliente_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4764 (class 2606 OID 19146)
-- Name: costi costi_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4765 (class 2606 OID 19141)
-- Name: costi costi_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_punti_deposito_fk FOREIGN KEY (deposito) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4762 (class 2606 OID 19136)
-- Name: disponibilita disponibilita_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4763 (class 2606 OID 19131)
-- Name: disponibilita disponibilita_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_punti_deposito_fk FOREIGN KEY (deposito) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4761 (class 2606 OID 18918)
-- Name: fatture fatture_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_cliente_fk FOREIGN KEY (cliente) REFERENCES develop.clienti(codice_fiscale);


--
-- TOC entry 4760 (class 2606 OID 19059)
-- Name: fornitori fornitori_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitori_punti_deposito_fk FOREIGN KEY (id) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4758 (class 2606 OID 19070)
-- Name: negozi negozi_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozi_punti_deposito_fk FOREIGN KEY (id) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4759 (class 2606 OID 18875)
-- Name: negozi negozio_manager_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozio_manager_fk FOREIGN KEY (manager) REFERENCES develop.manager(id);


--
-- TOC entry 4768 (class 2606 OID 19180)
-- Name: ordini ordini_fornitori_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_fornitori_fk FOREIGN KEY (fornitore) REFERENCES develop.fornitori(id);


--
-- TOC entry 4769 (class 2606 OID 19185)
-- Name: ordini ordini_negozi_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_negozi_fk FOREIGN KEY (negozio) REFERENCES develop.negozi(id);


--
-- TOC entry 4766 (class 2606 OID 18981)
-- Name: prodotti_fattura prodotti_fattura_fatture_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_fatture_fk FOREIGN KEY (fattura) REFERENCES develop.fatture(id);


--
-- TOC entry 4767 (class 2606 OID 19105)
-- Name: prodotti_fattura prodotti_fattura_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id) ON UPDATE CASCADE;


--
-- TOC entry 4770 (class 2606 OID 19200)
-- Name: prodotti_ordine prodotti_ordine_ordini_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_ordini_fk FOREIGN KEY (ordine) REFERENCES develop.ordini(id);


--
-- TOC entry 4771 (class 2606 OID 19205)
-- Name: prodotti_ordine prodotti_ordine_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4756 (class 2606 OID 18850)
-- Name: tessere tessera_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessera_cliente_fk FOREIGN KEY (proprietario) REFERENCES develop.clienti(codice_fiscale);


--
-- TOC entry 4757 (class 2606 OID 19076)
-- Name: tessere tessere_negozi_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessere_negozi_fk FOREIGN KEY (negozio_di_rilascio) REFERENCES develop.negozi(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4754 (class 2606 OID 18820)
-- Name: manager utenze_manager_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT utenze_manager_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4943 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA develop; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA develop TO webapp;


--
-- TOC entry 4944 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE clienti; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.clienti TO webapp;


--
-- TOC entry 4946 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE manager; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT ON TABLE develop.manager TO webapp;


--
-- TOC entry 4949 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE tessere; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT ON TABLE develop.tessere TO webapp;


--
-- TOC entry 4950 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE utenze; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE develop.utenze TO webapp;


-- Completed on 2025-06-21 17:00:51

--
-- PostgreSQL database dump complete
--

