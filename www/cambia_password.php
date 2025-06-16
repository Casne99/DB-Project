<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$messaggio = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $password_corrente = $_POST['password_corrente'] ?? '';
    $password_nuova = $_POST['password_nuova'] ?? '';
    $password_nuova_confirm = $_POST['password_nuova_confirm'] ?? '';
    $email = $_SESSION['user_email'];

    if ($password_nuova !== $password_nuova_confirm) {
        $messaggio = 'Le nuove password non coincidono.';
    } else {
        // Controlla che la password corrente sia corretta
        $pdo->exec("SET search_path = develop");
        $stmt = $pdo->prepare('SELECT password FROM utenze WHERE login = :email');
        $stmt->execute(['email' => $email]);
        $utente = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($utente && password_verify($password_corrente, $utente['password'])) {
            // Hash nuova password
            $hash = password_hash($password_nuova, PASSWORD_DEFAULT);

            // Aggiorna password nel DB
            $update = $pdo->prepare('UPDATE utenze SET password = :hash WHERE login = :email');
            if ($update->execute(['hash' => $hash, 'email' => $email])) {
                $messaggio = 'Password cambiata con successo.';
            } else {
                $messaggio = 'Errore durante l\'aggiornamento della password.';
            }
        } else {
            $messaggio = 'Password corrente errata.';
        }
    }
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Cambia Password</title>
</head>
<body>
<h2>Cambia Password</h2>

<?php if ($messaggio): ?>
    <p><?= htmlspecialchars($messaggio) ?></p>
<?php endif; ?>

<form method="POST" action="">
    <label for="password_corrente">Password corrente:</label><br>
    <input type="password" id="password_corrente" name="password_corrente" required><br><br>

    <label for="password_nuova">Nuova password:</label><br>
    <input type="password" id="password_nuova" name="password_nuova" required><br><br>

    <label for="password_nuova_confirm">Conferma nuova password:</label><br>
    <input type="password" id="password_nuova_confirm" name="password_nuova_confirm" required><br><br>

    <button type="submit">Cambia Password</button>
</form>

<p><a href="dashboard.php">Torna alla dashboard</a></p>
</body>
</html>
