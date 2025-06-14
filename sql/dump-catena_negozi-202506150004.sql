--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

-- Started on 2025-06-15 00:04:27

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
-- Name: cliente; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.cliente (
    nome character varying(100) NOT NULL,
    login character varying(60) NOT NULL,
    codice_fiscale character(16) NOT NULL
);


ALTER TABLE develop.cliente OWNER TO postgres;

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
-- TOC entry 4863 (class 0 OID 0)
-- Dependencies: 225
-- Name: fatture_id_seq; Type: SEQUENCE OWNED BY; Schema: develop; Owner: postgres
--

ALTER SEQUENCE develop.fatture_id_seq OWNED BY develop.fatture.id;


--
-- TOC entry 222 (class 1259 OID 18880)
-- Name: fornitore; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.fornitore (
    id integer NOT NULL,
    partita_iva character(11) NOT NULL
);


ALTER TABLE develop.fornitore OWNER TO postgres;

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
-- Name: negozio; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.negozio (
    id integer NOT NULL,
    orario_apertura time without time zone NOT NULL,
    orario_chiusura time without time zone NOT NULL,
    responsabile character varying(100) NOT NULL,
    manager integer NOT NULL
);


ALTER TABLE develop.negozio OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 18893)
-- Name: ordine; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.ordine (
    id integer NOT NULL,
    data_consegna date NOT NULL,
    negozio integer NOT NULL,
    fornitore integer NOT NULL
);


ALTER TABLE develop.ordine OWNER TO postgres;

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
-- TOC entry 4864 (class 0 OID 0)
-- Dependencies: 223
-- Name: ordine_id_seq; Type: SEQUENCE OWNED BY; Schema: develop; Owner: postgres
--

ALTER SEQUENCE develop.ordine_id_seq OWNED BY develop.ordine.id;


--
-- TOC entry 220 (class 1259 OID 18855)
-- Name: punto_deposito; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.punto_deposito (
    id integer NOT NULL,
    indirizzo character varying(120) NOT NULL
);


ALTER TABLE develop.punto_deposito OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 18844)
-- Name: tessera; Type: TABLE; Schema: develop; Owner: postgres
--

CREATE TABLE develop.tessera (
    punti integer DEFAULT 0 NOT NULL,
    data_richiesta date NOT NULL,
    proprietario character(16) NOT NULL,
    negozio_di_rilascio integer NOT NULL
);


ALTER TABLE develop.tessera OWNER TO postgres;

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
-- TOC entry 4671 (class 2604 OID 18914)
-- Name: fatture id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture ALTER COLUMN id SET DEFAULT nextval('develop.fatture_id_seq'::regclass);


--
-- TOC entry 4669 (class 2604 OID 18896)
-- Name: ordine id; Type: DEFAULT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordine ALTER COLUMN id SET DEFAULT nextval('develop.ordine_id_seq'::regclass);


--
-- TOC entry 4848 (class 0 OID 18834)
-- Dependencies: 218
-- Data for Name: cliente; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.cliente (nome, login, codice_fiscale) FROM stdin;
\.


--
-- TOC entry 4856 (class 0 OID 18910)
-- Dependencies: 226
-- Data for Name: fatture; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.fatture (sconto_applicato, totale, data_acquisto, id, cliente) FROM stdin;
\.


--
-- TOC entry 4852 (class 0 OID 18880)
-- Dependencies: 222
-- Data for Name: fornitore; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.fornitore (id, partita_iva) FROM stdin;
\.


--
-- TOC entry 4847 (class 0 OID 18815)
-- Dependencies: 217
-- Data for Name: manager; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.manager (id, nome, login) FROM stdin;
1	Mario Brambilla	mario.brambilla@protonmail.com
\.


--
-- TOC entry 4851 (class 0 OID 18860)
-- Dependencies: 221
-- Data for Name: negozio; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.negozio (id, orario_apertura, orario_chiusura, responsabile, manager) FROM stdin;
\.


--
-- TOC entry 4854 (class 0 OID 18893)
-- Dependencies: 224
-- Data for Name: ordine; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.ordine (id, data_consegna, negozio, fornitore) FROM stdin;
\.


--
-- TOC entry 4850 (class 0 OID 18855)
-- Dependencies: 220
-- Data for Name: punto_deposito; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.punto_deposito (id, indirizzo) FROM stdin;
\.


--
-- TOC entry 4849 (class 0 OID 18844)
-- Dependencies: 219
-- Data for Name: tessera; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.tessera (punti, data_richiesta, proprietario, negozio_di_rilascio) FROM stdin;
\.


--
-- TOC entry 4846 (class 0 OID 18810)
-- Dependencies: 216
-- Data for Name: utenze; Type: TABLE DATA; Schema: develop; Owner: postgres
--

COPY develop.utenze (login, password) FROM stdin;
mario.brambilla@protonmail.com	$2b$12$BlfkUex.b34CHgM03kvL0eE2b/z8b/tmIpBcU1B4E7G2BwkPpxU.a
caludio.gennari@gmail.com	$2b$12$VC3rIRGLGphbSasHU0AZEOU3VnZB3mTt2xKRDIeQwVwXy/.wCfN6C
\.


--
-- TOC entry 4866 (class 0 OID 0)
-- Dependencies: 225
-- Name: fatture_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.fatture_id_seq', 1, false);


--
-- TOC entry 4867 (class 0 OID 0)
-- Dependencies: 223
-- Name: ordine_id_seq; Type: SEQUENCE SET; Schema: develop; Owner: postgres
--

SELECT pg_catalog.setval('develop.ordine_id_seq', 1, false);


--
-- TOC entry 4678 (class 2606 OID 18838)
-- Name: cliente cliente_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.cliente
    ADD CONSTRAINT cliente_pk PRIMARY KEY (codice_fiscale);


--
-- TOC entry 4692 (class 2606 OID 18917)
-- Name: fatture fatture_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_pk PRIMARY KEY (id);


--
-- TOC entry 4686 (class 2606 OID 18884)
-- Name: fornitore fornitore_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitore
    ADD CONSTRAINT fornitore_pk PRIMARY KEY (id);


--
-- TOC entry 4688 (class 2606 OID 18886)
-- Name: fornitore fornitore_unique; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitore
    ADD CONSTRAINT fornitore_unique UNIQUE (partita_iva);


--
-- TOC entry 4684 (class 2606 OID 18864)
-- Name: negozio negozio_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozio
    ADD CONSTRAINT negozio_pk PRIMARY KEY (id);


--
-- TOC entry 4676 (class 2606 OID 18819)
-- Name: manager newtable_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT newtable_pk PRIMARY KEY (id);


--
-- TOC entry 4690 (class 2606 OID 18898)
-- Name: ordine ordine_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordine
    ADD CONSTRAINT ordine_pk PRIMARY KEY (id);


--
-- TOC entry 4682 (class 2606 OID 18859)
-- Name: punto_deposito punto_deposito_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.punto_deposito
    ADD CONSTRAINT punto_deposito_pk PRIMARY KEY (id);


--
-- TOC entry 4680 (class 2606 OID 18849)
-- Name: tessera tessera_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessera
    ADD CONSTRAINT tessera_pk PRIMARY KEY (proprietario);


--
-- TOC entry 4674 (class 2606 OID 18814)
-- Name: utenze utenze_pk; Type: CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.utenze
    ADD CONSTRAINT utenze_pk PRIMARY KEY (login);


--
-- TOC entry 4694 (class 2606 OID 18839)
-- Name: cliente cliente_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.cliente
    ADD CONSTRAINT cliente_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4702 (class 2606 OID 18918)
-- Name: fatture fatture_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fatture
    ADD CONSTRAINT fatture_cliente_fk FOREIGN KEY (cliente) REFERENCES develop.cliente(codice_fiscale);


--
-- TOC entry 4699 (class 2606 OID 18887)
-- Name: fornitore fornitore_punto_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.fornitore
    ADD CONSTRAINT fornitore_punto_deposito_fk FOREIGN KEY (id) REFERENCES develop.punto_deposito(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4697 (class 2606 OID 18875)
-- Name: negozio negozio_manager_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozio
    ADD CONSTRAINT negozio_manager_fk FOREIGN KEY (manager) REFERENCES develop.manager(id);


--
-- TOC entry 4698 (class 2606 OID 18865)
-- Name: negozio negozio_punto_deposito_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.negozio
    ADD CONSTRAINT negozio_punto_deposito_fk FOREIGN KEY (id) REFERENCES develop.punto_deposito(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4700 (class 2606 OID 18899)
-- Name: ordine ordine_fornitore_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordine
    ADD CONSTRAINT ordine_fornitore_fk FOREIGN KEY (fornitore) REFERENCES develop.fornitore(id);


--
-- TOC entry 4701 (class 2606 OID 18904)
-- Name: ordine ordine_negozio_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.ordine
    ADD CONSTRAINT ordine_negozio_fk FOREIGN KEY (negozio) REFERENCES develop.negozio(id);


--
-- TOC entry 4695 (class 2606 OID 18850)
-- Name: tessera tessera_cliente_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessera
    ADD CONSTRAINT tessera_cliente_fk FOREIGN KEY (proprietario) REFERENCES develop.cliente(codice_fiscale);


--
-- TOC entry 4696 (class 2606 OID 18870)
-- Name: tessera tessera_negozio_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.tessera
    ADD CONSTRAINT tessera_negozio_fk FOREIGN KEY (negozio_di_rilascio) REFERENCES develop.negozio(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4693 (class 2606 OID 18820)
-- Name: manager utenze_manager_utenze_fk; Type: FK CONSTRAINT; Schema: develop; Owner: postgres
--

ALTER TABLE ONLY develop.manager
    ADD CONSTRAINT utenze_manager_utenze_fk FOREIGN KEY (login) REFERENCES develop.utenze(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4862 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA develop; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA develop TO webapp;


--
-- TOC entry 4865 (class 0 OID 0)
-- Dependencies: 216
-- Name: TABLE utenze; Type: ACL; Schema: develop; Owner: postgres
--

GRANT SELECT ON TABLE develop.utenze TO webapp;


-- Completed on 2025-06-15 00:04:27

--
-- PostgreSQL database dump complete
--

