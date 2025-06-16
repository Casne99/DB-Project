--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

-- Started on 2025-06-16 21:47:29

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 218 (class 1259 OID 18834)
-- Name: clienti; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.clienti (
    nome character varying(100) NOT NULL,
    login character varying(60) NOT NULL,
    codice_fiscale character(16) NOT NULL
);


ALTER TABLE develop.clienti OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 18960)
-- Name: costi; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.costi (
    deposito character varying(7) NOT NULL,
    prodotto character varying(7) NOT NULL,
    prezzo numeric(8,2) DEFAULT 0 NOT NULL
);


ALTER TABLE develop.costi OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 18945)
-- Name: disponibilita; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.disponibilita (
    deposito character varying(7) NOT NULL,
    prodotto character varying(7) NOT NULL,
    quantita integer NOT NULL
);


ALTER TABLE develop.disponibilita OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 18910)
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
-- TOC entry 225 (class 1259 OID 18909)
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
-- TOC entry 4908 (class 0 OID 0)
-- Dependencies: 225
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
    login character varying(60) NOT NULL
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
    manager integer NOT NULL
);


ALTER TABLE develop.negozi OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 18893)
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
-- TOC entry 223 (class 1259 OID 18892)
-- Name: ordine_id_seq; Type: SEQUENCE; Schema: develop; Owner: postgres
--

CREATE SEQUENCE develop.ordine_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE develop.ordine_id_seq OWNER TO postgres;

--
-- TOC entry 4910 (class 0 OID 0)
-- Dependencies: 223
-- Name: ordine_id_seq; Type: SEQUENCE OWNED BY; Schema: develop; Owner: postgres
--

ALTER SEQUENCE develop.ordine_id_seq OWNED BY develop.ordini.id;


--
-- TOC entry 227 (class 1259 OID 18923)
-- Name: prodotti; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.prodotti (
    id character varying(7) NOT NULL,
    nome character varying(100) NOT NULL,
    descrizione text NOT NULL
);


ALTER TABLE develop.prodotti OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 18976)
-- Name: prodotti_fattura; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.prodotti_fattura (
    prodotto character varying(7) NOT NULL,
    fattura integer NOT NULL,
    quantita integer NOT NULL
);


ALTER TABLE develop.prodotti_fattura OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 18930)
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
-- TOC entry 216 (class 1259 OID 18810)
-- Name: utenze; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.utenze (
    login character varying(60) NOT NULL,
    password character varying(60) NOT NULL
);


ALTER TABLE develop.utenze OWNER TO postgres;

--
-- TOC entry 4691 (class 2604 OID 18914)
-- Name: fatture id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture ALTER COLUMN id SET DEFAULT nextval('develop.fatture_id_seq'::regclass);


--
-- TOC entry 4689 (class 2604 OID 18896)
-- Name: ordini id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini ALTER COLUMN id SET DEFAULT nextval('develop.ordine_id_seq'::regclass);


--
-- TOC entry 4887 (class 0 OID 18834)
-- Dependencies: 218
-- Data for Name: clienti; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.clienti (nome, login, codice_fiscale) FROM stdin;
Claudio Gennari	claudio.gennari@gmail.com	CLDGNR99C08F576W
Sara Brusaferri	sara.brusaferri@gmail.com	SRABRS98C08F576W
sara gianni	sara.gianni@gmail.com	GNNSRA95C55F205Z
\.


--
-- TOC entry 4899 (class 0 OID 18960)
-- Dependencies: 230
-- Data for Name: costi; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.costi (deposito, prodotto, prezzo) FROM stdin;
\.


--
-- TOC entry 4898 (class 0 OID 18945)
-- Dependencies: 229
-- Data for Name: disponibilita; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.disponibilita (deposito, prodotto, quantita) FROM stdin;
\.


--
-- TOC entry 4895 (class 0 OID 18910)
-- Dependencies: 226
-- Data for Name: fatture; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.fatture (sconto_applicato, totale, data_acquisto, id, cliente) FROM stdin;
\.


--
-- TOC entry 4891 (class 0 OID 18880)
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
-- TOC entry 4886 (class 0 OID 18815)
-- Dependencies: 217
-- Data for Name: manager; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.manager (id, nome, login) FROM stdin;
1	Mario Brambilla	mario.brambilla@protonmail.com
\.


--
-- TOC entry 4890 (class 0 OID 18860)
-- Dependencies: 221
-- Data for Name: negozi; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.negozi (id, orario_apertura, orario_chiusura, responsabile, manager) FROM stdin;
01JTS13	09:00:00	18:00:00	Davide Fontana	1
01JTS01	08:00:00	18:00:00	Mario Rossi	1
01JTS02	08:30:00	17:30:00	Luisa Bianchi	1
01JTS03	09:00:00	18:00:00	Giovanni Verdi	1
01JTS04	08:00:00	17:00:00	Chiara Neri	1
01JTS05	07:30:00	16:30:00	Federico Gallo	1
01JTS06	08:00:00	17:00:00	Elena Russo	1
01JTS07	09:00:00	18:00:00	Luca Conti	1
01JTS08	08:30:00	17:30:00	Sara Costa	1
01JTS09	08:00:00	16:00:00	Alessandro Greco	1
01JTS10	07:00:00	15:00:00	Martina De Luca	1
01JTS11	08:00:00	17:00:00	Giorgio Rinaldi	1
01JTS12	08:00:00	17:00:00	Francesca Moretti	1
\.


--
-- TOC entry 4893 (class 0 OID 18893)
-- Dependencies: 224
-- Data for Name: ordini; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.ordini (id, data_consegna, negozio, fornitore) FROM stdin;
\.


--
-- TOC entry 4896 (class 0 OID 18923)
-- Dependencies: 227
-- Data for Name: prodotti; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti (id, nome, descrizione) FROM stdin;
\.


--
-- TOC entry 4900 (class 0 OID 18976)
-- Dependencies: 231
-- Data for Name: prodotti_fattura; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti_fattura (prodotto, fattura, quantita) FROM stdin;
\.


--
-- TOC entry 4897 (class 0 OID 18930)
-- Dependencies: 228
-- Data for Name: prodotti_ordine; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.prodotti_ordine (quantita, ordine, prodotto) FROM stdin;
\.


--
-- TOC entry 4889 (class 0 OID 18855)
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
-- TOC entry 4888 (class 0 OID 18844)
-- Dependencies: 219
-- Data for Name: tessere; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.tessere (punti, data_richiesta, proprietario, negozio_di_rilascio) FROM stdin;
\.


--
-- TOC entry 4885 (class 0 OID 18810)
-- Dependencies: 216
-- Data for Name: utenze; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.utenze (login, password) FROM stdin;
claudio.gennari@gmail.com	$2b$12$VC3rIRGLGphbSasHU0AZEOU3VnZB3mTt2xKRDIeQwVwXy/.wCfN6C
sara.brusaferri@gmail.com	$2b$12$zoyCynJrJx0/FjIRtp2s.eqL5NkSNLMloMfGPnC7t/ejlh1XxR0DC
sara.gianni@gmail.com	$2y$10$saJehlmBIZDwWkhIM4ojoOTdTnxhxiVggbKkW2dkcNtNx3siW0r9e
mario.brambilla@protonmail.com	$2y$10$/llMa72HAQBNJoKLiPlssuSVxcMgSBqegAPCuXXdOdnLxYdRH.4km
\.


--
-- TOC entry 4912 (class 0 OID 0)
-- Dependencies: 225
-- Name: fatture_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.fatture_id_seq', 1, false);


--
-- TOC entry 4913 (class 0 OID 0)
-- Dependencies: 223
-- Name: ordine_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.ordine_id_seq', 1, false);


--
-- TOC entry 4699 (class 2606 OID 18838)
-- Name: clienti cliente_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.clienti
    ADD CONSTRAINT cliente_pk PRIMARY KEY (codice_fiscale);


--
-- TOC entry 4721 (class 2606 OID 19028)
-- Name: costi costi_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_pk PRIMARY KEY (deposito, prodotto);


--
-- TOC entry 4719 (class 2606 OID 19014)
-- Name: disponibilita disponibilita_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_pk PRIMARY KEY (prodotto, deposito);


--
-- TOC entry 4713 (class 2606 OID 18917)
-- Name: fatture fatture_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_pk PRIMARY KEY (id);


--
-- TOC entry 4707 (class 2606 OID 19053)
-- Name: fornitori fornitore_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitore_pk PRIMARY KEY (id);


--
-- TOC entry 4709 (class 2606 OID 18886)
-- Name: fornitori fornitore_unique; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitore_unique UNIQUE (partita_iva);


--
-- TOC entry 4705 (class 2606 OID 19065)
-- Name: negozi negozio_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozio_pk PRIMARY KEY (id);


--
-- TOC entry 4697 (class 2606 OID 18819)
-- Name: manager newtable_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT newtable_pk PRIMARY KEY (id);


--
-- TOC entry 4711 (class 2606 OID 18898)
-- Name: ordini ordine_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordine_pk PRIMARY KEY (id);


--
-- TOC entry 4723 (class 2606 OID 19100)
-- Name: prodotti_fattura prodotti_fattura_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_pk PRIMARY KEY (prodotto, fattura);


--
-- TOC entry 4717 (class 2606 OID 19121)
-- Name: prodotti_ordine prodotti_ordine_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_pk PRIMARY KEY (ordine, prodotto);


--
-- TOC entry 4715 (class 2606 OID 19092)
-- Name: prodotti prodotti_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti
    ADD CONSTRAINT prodotti_pk PRIMARY KEY (id);


--
-- TOC entry 4703 (class 2606 OID 19034)
-- Name: punti_deposito punto_deposito_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.punti_deposito
    ADD CONSTRAINT punto_deposito_pk PRIMARY KEY (id);


--
-- TOC entry 4701 (class 2606 OID 18849)
-- Name: tessere tessera_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessera_pk PRIMARY KEY (proprietario);


--
-- TOC entry 4695 (class 2606 OID 18814)
-- Name: utenze utenze_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.utenze
    ADD CONSTRAINT utenze_pk PRIMARY KEY (login);


--
-- TOC entry 4725 (class 2606 OID 18839)
-- Name: clienti cliente_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.clienti
    ADD CONSTRAINT cliente_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4738 (class 2606 OID 19146)
-- Name: costi costi_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4739 (class 2606 OID 19141)
-- Name: costi costi_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.costi
    ADD CONSTRAINT costi_punti_deposito_fk FOREIGN KEY (deposito) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4736 (class 2606 OID 19136)
-- Name: disponibilita disponibilita_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4737 (class 2606 OID 19131)
-- Name: disponibilita disponibilita_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.disponibilita
    ADD CONSTRAINT disponibilita_punti_deposito_fk FOREIGN KEY (deposito) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4733 (class 2606 OID 18918)
-- Name: fatture fatture_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_cliente_fk FOREIGN KEY (cliente) REFERENCES develop.clienti(codice_fiscale);


--
-- TOC entry 4730 (class 2606 OID 19059)
-- Name: fornitori fornitori_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitori
    ADD CONSTRAINT fornitori_punti_deposito_fk FOREIGN KEY (id) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4728 (class 2606 OID 19070)
-- Name: negozi negozi_punti_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozi_punti_deposito_fk FOREIGN KEY (id) REFERENCES develop.punti_deposito(id);


--
-- TOC entry 4729 (class 2606 OID 18875)
-- Name: negozi negozio_manager_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozi
    ADD CONSTRAINT negozio_manager_fk FOREIGN KEY (manager) REFERENCES develop.manager(id);


--
-- TOC entry 4731 (class 2606 OID 19110)
-- Name: ordini ordini_fornitori_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_fornitori_fk FOREIGN KEY (fornitore) REFERENCES develop.fornitori(id);


--
-- TOC entry 4732 (class 2606 OID 19115)
-- Name: ordini ordini_negozi_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordini
    ADD CONSTRAINT ordini_negozi_fk FOREIGN KEY (negozio) REFERENCES develop.negozi(id);


--
-- TOC entry 4740 (class 2606 OID 18981)
-- Name: prodotti_fattura prodotti_fattura_fatture_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_fatture_fk FOREIGN KEY (fattura) REFERENCES develop.fatture(id);


--
-- TOC entry 4741 (class 2606 OID 19105)
-- Name: prodotti_fattura prodotti_fattura_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_fattura
    ADD CONSTRAINT prodotti_fattura_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id) ON UPDATE CASCADE;


--
-- TOC entry 4734 (class 2606 OID 18940)
-- Name: prodotti_ordine prodotti_ordine_ordini_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_ordini_fk FOREIGN KEY (ordine) REFERENCES develop.ordini(id);


--
-- TOC entry 4735 (class 2606 OID 19126)
-- Name: prodotti_ordine prodotti_ordine_prodotti_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.prodotti_ordine
    ADD CONSTRAINT prodotti_ordine_prodotti_fk FOREIGN KEY (prodotto) REFERENCES develop.prodotti(id);


--
-- TOC entry 4726 (class 2606 OID 18850)
-- Name: tessere tessera_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessera_cliente_fk FOREIGN KEY (proprietario) REFERENCES develop.clienti(codice_fiscale);


--
-- TOC entry 4727 (class 2606 OID 19076)
-- Name: tessere tessere_negozi_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessere
    ADD CONSTRAINT tessere_negozi_fk FOREIGN KEY (negozio_di_rilascio) REFERENCES develop.negozi(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4724 (class 2606 OID 18820)
-- Name: manager utenze_manager_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT utenze_manager_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4906 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA develop; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA develop TO webapp;


--
-- TOC entry 4907 (class 0 OID 0)
-- Dependencies: 218
-- Name: TABLE clienti; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE develop.clienti TO webapp;


--
-- TOC entry 4909 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE manager; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT ON TABLE develop.manager TO webapp;


--
-- TOC entry 4911 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE utenze; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE develop.utenze TO webapp;


-- Completed on 2025-06-16 21:47:29

--
-- PostgreSQL database dump complete
--

