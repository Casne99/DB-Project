<?php
session_start();

require_once __DIR__ . '/config/db.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = $_POST['email'] ?? '';
    $password = $_POST['password'] ?? '';

    $pdo->exec("SET search_path = develop");

    $stmt = $pdo->prepare('SELECT password FROM develop.utenze WHERE login = :email');
    $stmt->execute(['email' => $email]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($result && isset($result['password'])) {
        $hashSalvato = $result['password'];

        if (password_verify($password, $hashSalvato)) {
            $_SESSION['user_email'] = $email;
            $_SESSION['logged_in'] = true;
            echo "Accesso consentito. Benvenuto, " . htmlspecialchars($email) . "!";
        } else {
            echo "Password errata.";
        }
    } else {
        echo "Utente non trovato.";
    }
} else {
    echo "Metodo di richiesta non valido.";
}
