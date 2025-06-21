<?php

function get_user_role(PDO $pdo, string $login): UserRole
{
    $pdo->exec("SET search_path = develop");

    $stmt = $pdo->prepare("SELECT 1 FROM develop.clienti WHERE login = :login");
    $stmt->execute(['login' => $login]);
    if ($stmt->fetch()) {
        return UserRole::Cliente;
    }

    $stmt = $pdo->prepare("SELECT 1 FROM develop.manager WHERE login = :login");
    $stmt->execute(['login' => $login]);
    if ($stmt->fetch()) {
        return UserRole::Manager;
    }

    return UserRole::Unknown;
}

// TODO: restringere modifica password da parte di un manager ai soli clienti e non ai manager stessi
function add_user(PDO $pdo, string $email, string $password, string $nome, string $cognome, string $codiceFiscale, string $genere): bool
{
    $logFile = __DIR__ . '/app_debug.log';
    $log = fn($message) => error_log(date('[Y-m-d H:i:s] ') . $message . PHP_EOL, 3, $logFile);

    $log("Inizio funzione add_user con email: $email");

    $pdo->beginTransaction();
    try {
        $pdo->exec("SET search_path = develop");
        $log("Impostato search_path a develop");

        $stmt = $pdo->prepare("SELECT 1 FROM develop.utenze WHERE login = :email");
        $stmt->execute(['email' => $email]);
        if ($stmt->fetch()) {
            $log("Utente già esistente con login: $email");
            throw new Exception("Utente già esistente.");
        }

        $hashPassword = password_hash($password, PASSWORD_DEFAULT);
        $log("Password hash generato");

        $stmt = $pdo->prepare("
            INSERT INTO develop.utenze (login, password)
            VALUES (:email, :password)
        ");
        $stmt->execute([
            'email' => $email,
            'password' => $hashPassword
        ]);
        $log("Inserito in develop.utenze: $email");

        $stmt = $pdo->prepare("
            INSERT INTO develop.clienti (login, nome, cognome, codice_fiscale, genere)
            VALUES (:email, :nome, :cognome, :cf, :genere)
        ");
        $stmt->execute([
            'email' => $email,
            'nome' => $nome,
            'cognome' => $cognome,
            'cf' => $codiceFiscale,
            'genere' => $genere
        ]);
        $log("Inserito in develop.clienti: $email - $nome $cognome - $codiceFiscale - $genere");

        $pdo->commit();
        $log("Transazione completata con successo");
        return true;

    } catch (Exception $e) {
        $pdo->rollBack();
        $log("ERRORE: Transazione annullata - " . $e->getMessage());
        return false;
    }
}

function update_cliente(PDO $pdo, string $email, string $nome, string $cognome, string $codiceFiscale, string $genere): bool
{
    $logFile = __DIR__ . '/app_debug.log';
    $log = fn($message) => error_log(date('[Y-m-d H:i:s] ') . $message . PHP_EOL, 3, $logFile);

    $log("Inizio funzione update_cliente per: $email");

    try {
        $pdo->beginTransaction();
        $pdo->exec("SET search_path = develop");
        $log("Impostato search_path a develop");

        // Verifica che l’utente sia un cliente
        $stmt = $pdo->prepare("SELECT 1 FROM develop.clienti WHERE login = :email");
        $stmt->execute(['email' => $email]);
        if (!$stmt->fetch()) {
            $log("Nessun cliente trovato con login: $email");
            throw new Exception("Utente non è un cliente.");
        }

        // Aggiorna i dati del cliente
        $stmt = $pdo->prepare("
            UPDATE develop.clienti
            SET nome = :nome, cognome = :cognome, codice_fiscale = :cf, genere = :genere
            WHERE login = :email
        ");
        $stmt->execute([
            'email' => $email,
            'nome' => $nome,
            'cognome' => $cognome,
            'cf' => $codiceFiscale,
            'genere' => $genere
        ]);

        $pdo->commit();
        $log("Dati cliente aggiornati con successo per: $email");
        return true;

    } catch (Exception $e) {
        $pdo->rollBack();
        $log("ERRORE nella funzione update_cliente: " . $e->getMessage());
        return false;
    }
}





enum UserRole: string
{
    case Cliente = 'cliente';
    case Manager = 'manager';
    case Unknown = 'unknown';

    public function isKnown(): bool
    {
        return $this !== self::Unknown;
    }
}

