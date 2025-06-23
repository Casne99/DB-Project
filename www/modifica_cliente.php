<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$pdo->exec("SET search_path = develop");

$message = '';
$cliente = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = $_POST['email'] ?? '';

    if (isset($_POST['load'])) {
        $stmt = $pdo->prepare("SELECT * FROM clienti WHERE login = :email");
        $stmt->execute(['email' => $email]);
        $cliente = $stmt->fetch();
        if (!$cliente) {
            $message = "Cliente non trovato.";
        }
    } elseif (isset($_POST['save'])) {
        $stmt = $pdo->prepare("
            UPDATE clienti
            SET nome = :nome, cognome = :cognome, codice_fiscale = :cf, genere = :genere
            WHERE login = :email
        ");
        try {
            $stmt->execute([
                'email' => $_POST['email'],
                'nome' => $_POST['nome'],
                'cognome' => $_POST['cognome'],
                'cf' => $_POST['codice_fiscale'],
                'genere' => $_POST['genere']
            ]);
            $message = "Dati aggiornati con successo.";
        } catch (PDOException $e) {
            $message = "Errore durante l'aggiornamento: " . htmlspecialchars($e->getMessage());
        }
    }
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Modifica Cliente</title>
    <style>
        .form-field {
            margin-bottom: 1.2em;
        }
        label {
            display: block;
            margin-bottom: 0.3em;
            font-weight: bold;
        }
        .form-buttons {
            margin-top: 1em;
        }
    </style>
</head>
<body>
    <h1>Modifica Cliente</h1>

    <?php if ($message): ?>
        <p><?= htmlspecialchars($message) ?></p>
    <?php endif; ?>

    <form method="POST">
        <div class="form-field">
            <label for="email">Email cliente:</label>
            <input type="email" id="email" name="email" value="<?= htmlspecialchars($_POST['email'] ?? '') ?>" required>
        </div>

        <div class="form-buttons">
            <button type="submit" name="load">Carica</button>
        </div>
    </form>

    <?php if ($cliente): ?>
        <form method="POST">
            <input type="hidden" name="email" value="<?= htmlspecialchars($cliente['login']) ?>">

            <div class="form-field">
                <label for="nome">Nome:</label>
                <input type="text" id="nome" name="nome" value="<?= htmlspecialchars($cliente['nome']) ?>" required>
            </div>

            <div class="form-field">
                <label for="cognome">Cognome:</label>
                <input type="text" id="cognome" name="cognome" value="<?= htmlspecialchars($cliente['cognome']) ?>" required>
            </div>

            <div class="form-field">
                <label for="codice_fiscale">Codice Fiscale:</label>
                <input type="text" id="codice_fiscale" name="codice_fiscale" value="<?= htmlspecialchars($cliente['codice_fiscale']) ?>" required>
            </div>

            <div class="form-field">
                <label for="genere">Genere:</label>
                <select id="genere" name="genere" required>
                    <option value="M" <?= $cliente['genere'] === 'M' ? 'selected' : '' ?>>Maschio</option>
                    <option value="F" <?= $cliente['genere'] === 'F' ? 'selected' : '' ?>>Femmina</option>
                </select>
            </div>

            <div class="form-buttons">
                <button type="submit" name="save">Salva Modifiche</button>
            </div>
        </form>
    <?php endif; ?>

    <p><a href="gestione_clienti.php">Torna alla Gestione Clienti</a></p>
</body>
</html>
