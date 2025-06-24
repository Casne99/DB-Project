-- Script per creare l'utente webapp necessario per l'applicazione
-- Eseguire questo script PRIMA di importare il dump del database

-- Crea l'utente webapp con password
CREATE USER webapp WITH PASSWORD 'webapp123';

-- Nota: i permessi specifici verranno assegnati durante l'importazione del dump