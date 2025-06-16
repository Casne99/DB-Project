<?php
session_start();

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/../utils/php/utils.php'; // se lì hai definito `add_user`

if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

$messaggio = '';
$successo = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    $nomeCompleto = trim($_POST['nome_completo'] ?? '');
    $codiceFiscale = strtoupper(trim($_POST['codice_fiscale'] ?? ''));

    if ($email && $password && $nomeCompleto && $codiceFiscale) {
        if (add_user($pdo, $email, $password, $nomeCompleto, $codiceFiscale)) {
            $messaggio = "Cliente aggiunto con successo.";
            $successo = true;
        } else {
            $messaggio = "Errore durante l'aggiunta del cliente. Verificare i log.";
        }
    } else {
        $messaggio = "Tutti i campi sono obbligatori.";
    }
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Aggiungi Cliente</title>
</head>
<body>
    <h1>Aggiungi Nuovo Cliente</h1>

    <?php if ($messaggio): ?>
        <p style="color:<?= $successo ? 'green' : 'red' ?>;"><?= htmlspecialchars($messaggio) ?></p>
    <?php endif; ?>

    <form method="POST" action="add_user.php">
        <label for="email">Email:</label><br>
        <input type="email" id="email" name="email" required><br><br>

        <label for="password">Password:</label><br>
        <input type="password" id="password" name="password" required><br><br>

        <label for="nome_completo">Nome e Cognome:</label><br>
        <input type="text" id="nome_completo" name="nome_completo" required><br><br>

        <label for="codice_fiscale">Codice Fiscale:</label><br>
        <input type="text" id="codice_fiscale" name="codice_fiscale" required maxlength="16"><br><br>

        <button type="submit">Aggiungi Cliente</button>
    </form>

    <p><a href="gestione_clienti.php">Torna alla Gestione Clienti</a></p>
</body>
</html>
