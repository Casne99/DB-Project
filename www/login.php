<?php
session_start();

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/../utils/php/utils.php';


$messaggio = '';

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

            $ruolo = get_user_role($pdo, $email);
            if (!$ruolo) {
                session_destroy();
                die("Ruolo non assegnato all'utente.");
            }
            $_SESSION['user_role'] = $ruolo;

            header('Location: dashboard.php');
            exit;
        } else {
            $messaggio = "Password errata.";
        }
    } else {
        $messaggio = "Utente non trovato.";
    }
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Login</title>
</head>
<body>
<h2>Login</h2>

<?php if ($messaggio): ?>
    <p style="color:red;"><?= htmlspecialchars($messaggio) ?></p>
<?php endif; ?>

<form action="login.php" method="POST">
    <label for="email">Email:</label><br>
    <input type="email" id="email" name="email" required
           value="<?= isset($email) ? htmlspecialchars($email) : '' ?>"><br><br>

    <label for="password">Password:</label><br>
    <input type="password" id="password" name="password" required><br><br>

    <button type="submit">Accedi</button>
</form>
</body>
</html>
