<?php

require 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = $_POST['email'] ?? '';
    $password = $_POST['password'] ?? '';

    try {
        $pdo = new PDO("pgsql:host=$host;dbname=$dbname", $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        ]);

        $pdo->exec("SET search_path = develop");

    } catch (PDOException $e) {
        die("Errore di connessione al database: " . $e->getMessage());
    }


    $stmt = $pdo->prepare('SELECT password FROM develop.utenze WHERE login = :email');
    $stmt->execute(['email' => $email]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($result && isset($result['password'])) {
        $hashSalvato = $result['password'];

        if (password_verify($password, $hashSalvato)) {
            echo "Accesso consentito. Benvenuto, " . htmlspecialchars($email) . "!";
            // Qui potrebbe iniziare una sessione o altro...
        } else {
            echo "Password errata.";
        }
    } else {
        echo "Utente non trovato.";
    }
} else {
    echo "Metodo di richiesta non valido.";
}
?>
