<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';
$pdo->exec("SET search_path = develop");

$msg = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (isset($_POST['crea_negozio'])) {
            $id = $_POST['id'] ?? '';
            $indirizzo = $_POST['indirizzo'] ?? '';
            $apertura = $_POST['orario_apertura'] ?? '';
            $chiusura = $_POST['orario_chiusura'] ?? '';
            $responsabile = $_POST['responsabile'] ?? '';
            $manager = $_SESSION['user_id'] ?? null;

            if (!$id || !$indirizzo || !$apertura || !$chiusura || !$responsabile || !$manager) {
                throw new Exception("Tutti i campi del negozio sono obbligatori.");
            }

            $pdo->beginTransaction();

            $stmt1 = $pdo->prepare("INSERT INTO punti_deposito (id, indirizzo) VALUES (:id, :indirizzo)");
            $stmt1->execute([':id' => $id, ':indirizzo' => $indirizzo]);

            $stmt2 = $pdo->prepare("
                INSERT INTO negozi (id, orario_apertura, orario_chiusura, responsabile, manager)
                VALUES (:id, :apertura, :chiusura, :responsabile, :manager)
            ");
            $stmt2->execute([
                ':id' => $id,
                ':apertura' => $apertura,
                ':chiusura' => $chiusura,
                ':responsabile' => $responsabile,
                ':manager' => $manager
            ]);

            $pdo->commit();
            $msg = "Negozio creato con successo.";

        } elseif (isset($_POST['crea_fornitore'])) {
            $id = $_POST['id'] ?? '';
            $indirizzo = $_POST['indirizzo'] ?? '';
            $piva = $_POST['partita_iva'] ?? '';

            if (!$id || !$indirizzo || !$piva) {
                throw new Exception("Tutti i campi del fornitore sono obbligatori.");
            }

            $pdo->beginTransaction();

            $stmt1 = $pdo->prepare("INSERT INTO punti_deposito (id, indirizzo) VALUES (:id, :indirizzo)");
            $stmt1->execute([':id' => $id, ':indirizzo' => $indirizzo]);

            $stmt2 = $pdo->prepare("INSERT INTO fornitori (id, partita_iva) VALUES (:id, :piva)");
            $stmt2->execute([':id' => $id, ':piva' => $piva]);

            $pdo->commit();
            $msg = "Fornitore creato con successo.";
        }
    } catch (Exception $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        $msg = "Errore: " . htmlspecialchars($e->getMessage());
    }
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Report Manager</title>
    <style>
        body {
            font-family: Arial, sans-serif;
        }
        .container {
            display: flex;
            gap: 40px;
            justify-content: flex-start;
            align-items: flex-start;
            margin-top: 20px;
        }
        form {
            border: 1px solid #ccc;
            padding: 15px;
            border-radius: 5px;
            width: 350px;
            box-sizing: border-box;
        }
        form h2 {
            margin-top: 0;
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 6px;
            font-weight: bold;
        }
        input[type="text"],
        input[type="time"],
        input[type="number"] {
            width: 100%;
            padding: 6px;
            margin-bottom: 12px;
            box-sizing: border-box;
            border: 1px solid #aaa;
            border-radius: 3px;
            font-size: 14px;
        }
        button {
            padding: 8px 16px;
            background-color: #2e6da4;
            color: white;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            font-size: 15px;
        }
        button:hover {
            background-color: #204d74;
        }
        .message {
            margin-top: 15px;
            padding: 10px;
            border-radius: 4px;
            background-color: #e7f3fe;
            border: 1px solid #b3d7ff;
            color: #31708f;
        }
    </style>
</head>
<body>
    <h1>Gestione negozi e fornitori</h1>

    <?php if ($msg): ?>
        <div class="message"><?= htmlspecialchars($msg) ?></div>
    <?php endif; ?>

    <div class="container">
        <form method="POST" novalidate>
            <h2>Crea nuovo negozio</h2>
            <input type="hidden" name="crea_negozio" value="1">

            <label for="id_negozio">ID (7 caratteri):</label>
            <input type="text" id="id_negozio" name="id" maxlength="7" required>

            <label for="indirizzo_negozio">Indirizzo:</label>
            <input type="text" id="indirizzo_negozio" name="indirizzo" maxlength="120" required>

            <label for="apertura">Orario apertura:</label>
            <input type="time" id="apertura" name="orario_apertura" required>

            <label for="chiusura">Orario chiusura:</label>
            <input type="time" id="chiusura" name="orario_chiusura" required>

            <label for="responsabile">Responsabile:</label>
            <input type="text" id="responsabile" name="responsabile" maxlength="100" required>

            <button type="submit">Crea Negozio</button>
        </form>

        <form method="POST" novalidate>
            <h2>Crea nuovo fornitore</h2>
            <input type="hidden" name="crea_fornitore" value="1">

            <label for="id_fornitore">ID (7 caratteri):</label>
            <input type="text" id="id_fornitore" name="id" maxlength="7" required>

            <label for="indirizzo_fornitore">Indirizzo:</label>
            <input type="text" id="indirizzo_fornitore" name="indirizzo" maxlength="120" required>

            <label for="piva">Partita IVA (11 cifre):</label>
            <input type="text" id="piva" name="partita_iva" maxlength="11" pattern="\d{11}" required>

            <button type="submit">Crea Fornitore</button>
        </form>
    </div>

    <p><a href="dashboard.php">Torna alla dashboard</a></p>
</body>
</html>
