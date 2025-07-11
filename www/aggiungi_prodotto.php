<?php
session_start();
if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';
$pdo->exec("SET search_path = develop");

$msg = $_SESSION['msg'] ?? '';
unset($_SESSION['msg']);

try {
    $stmtN = $pdo->query("SELECT id FROM negozi WHERE attivo = true ORDER BY id");
    $negozi = $stmtN->fetchAll();

    $stmtP = $pdo->query("SELECT id, nome FROM prodotti ORDER BY id");
    $prodotti = $stmtP->fetchAll();

    $stmtPrezzi = $pdo->query("
        SELECT c.deposito, c.prodotto, p.nome, c.prezzo
        FROM costi c
        JOIN prodotti p ON c.prodotto = p.id
        JOIN negozi n ON c.deposito = n.id
        ORDER BY c.deposito, c.prodotto
    ");
    $prezzi = $stmtPrezzi->fetchAll();
} catch (PDOException $e) {
    die("Errore database: " . htmlspecialchars($e->getMessage()));
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (isset($_POST['azione'])) {
            if ($_POST['azione'] === 'aggiungi_prodotto') {
                $id = trim($_POST['id'] ?? '');
                $nome = trim($_POST['nome'] ?? '');
                $descrizione = trim($_POST['descrizione'] ?? '');

                if (!$id || !$nome || !$descrizione) {
                    throw new Exception("Tutti i campi del prodotto sono obbligatori.");
                }

                if (strlen($id) !== 7) {
                    throw new Exception("L'ID prodotto deve essere di 7 caratteri.");
                }

                $stmt = $pdo->prepare("INSERT INTO prodotti (id, nome, descrizione) VALUES (:id, :nome, :descrizione)");
                $stmt->execute([
                    ':id' => $id,
                    ':nome' => $nome,
                    ':descrizione' => $descrizione
                ]);

                $_SESSION['msg'] = "Prodotto aggiunto con successo.";
                header("Location: " . $_SERVER['PHP_SELF']);
                exit;

            } elseif ($_POST['azione'] === 'imposta_prezzo') {
                $id_negozio = $_POST['id_negozio'] ?? '';
                $id_prodotto = $_POST['id_prodotto'] ?? '';
                $prezzo = $_POST['prezzo'] ?? '';

                if (!$id_negozio || !$id_prodotto || $prezzo === '') {
                    throw new Exception("Tutti i campi per il prezzo sono obbligatori.");
                }

                if (!is_numeric($prezzo) || $prezzo < 0) {
                    throw new Exception("Il prezzo deve essere un numero positivo.");
                }

                $stmt = $pdo->prepare("
                    INSERT INTO costi (deposito, prodotto, prezzo)
                    VALUES (:deposito, :prodotto, :prezzo)
                    ON CONFLICT (deposito, prodotto) DO UPDATE SET prezzo = EXCLUDED.prezzo
                ");
                $stmt->execute([
                    ':deposito' => $id_negozio,
                    ':prodotto' => $id_prodotto,
                    ':prezzo' => $prezzo
                ]);

                $_SESSION['msg'] = "Prezzo impostato con successo.";
                header("Location: " . $_SERVER['PHP_SELF']);
                exit;
            }
        }
    } catch (Exception $e) {
        $msg = "Errore: " . htmlspecialchars($e->getMessage());
    }
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Gestione Prodotti e Prezzi</title>
    <style>
        body {
            font-family: Arial, sans-serif;
        }
        h1 {
            margin-top: 15px;
        }
        .container {
            display: flex;
            gap: 40px;
            margin-top: 20px;
            flex-wrap: wrap;
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
        input[type="number"],
        select,
        textarea {
            width: 100%;
            padding: 6px;
            margin-bottom: 12px;
            box-sizing: border-box;
            border: 1px solid #aaa;
            border-radius: 3px;
            font-size: 14px;
            resize: vertical;
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
            max-width: 1100px;
        }
        .tabella-prezzi-container {
            width: 400px;
            border: 1px solid #ccc;
            border-radius: 5px;
            max-height: 350px;
            overflow-y: auto;
            padding-right: 10px;
            padding-left: 10px;
            padding-bottom: 10px;
        }
        .tabella-prezzi {
            width: 100%;
            border-collapse: collapse;
        }
        .tabella-prezzi th,
        .tabella-prezzi td {
            border: 1px solid #aaa;
            padding: 8px;
            text-align: left;
        }
        .tabella-prezzi th {
            background-color: #f2f2f2;
            position: sticky;
            top: 0;
            z-index: 1;
        }
    </style>
</head>
<body>
<h1>Gestione Prodotti e Prezzi</h1>

<?php if ($msg): ?>
    <div class="message"><?= $msg ?></div>
<?php endif; ?>

<div class="container">
    <!-- Form aggiunta prodotto -->
    <form method="POST">
        <h2>Aggiungi Nuovo Prodotto</h2>
        <input type="hidden" name="azione" value="aggiungi_prodotto">

        <label for="id">ID prodotto (7 caratteri):</label>
        <input type="text" id="id" name="id" maxlength="7" required>

        <label for="nome">Nome prodotto:</label>
        <input type="text" id="nome" name="nome" required>

        <label for="descrizione">Descrizione:</label>
        <textarea id="descrizione" name="descrizione" rows="4" required></textarea>

        <button type="submit">Aggiungi prodotto</button>
    </form>

    <!-- Form impostazione prezzo -->
    <form method="POST">
        <h2>Imposta Prezzo Prodotto per Negozio</h2>
        <input type="hidden" name="azione" value="imposta_prezzo">

        <label for="id_negozio">Seleziona negozio:</label>
        <select id="id_negozio" name="id_negozio" required>
            <option value="" disabled selected>-- scegli negozio --</option>
            <?php foreach ($negozi as $negozio): ?>
                <option value="<?= htmlspecialchars($negozio['id']) ?>"><?= htmlspecialchars($negozio['id']) ?></option>
            <?php endforeach; ?>
        </select>

        <label for="id_prodotto">Seleziona prodotto:</label>
        <select id="id_prodotto" name="id_prodotto" required>
            <option value="" disabled selected>-- scegli prodotto --</option>
            <?php foreach ($prodotti as $prodotto): ?>
                <option value="<?= htmlspecialchars($prodotto['id']) ?>">
                    <?= htmlspecialchars($prodotto['id']) ?> - <?= htmlspecialchars($prodotto['nome']) ?>
                </option>
            <?php endforeach; ?>
        </select>

        <label for="prezzo">Prezzo (€):</label>
        <input type="number" id="prezzo" name="prezzo" step="0.01" min="0" required>

        <button type="submit">Imposta prezzo</button>
    </form>

    <!-- Tabella prezzi attuali -->
    <div class="tabella-prezzi-container">
        <table class="tabella-prezzi">
            <thead>
                <tr>
                    <th>Negozio</th>
                    <th>ID prodotto</th>
                    <th>Nome</th>
                    <th>Prezzo (€)</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($prezzi as $riga): ?>
                    <tr>
                        <td><?= htmlspecialchars($riga['deposito']) ?></td>
                        <td><?= htmlspecialchars($riga['prodotto']) ?></td>
                        <td><?= htmlspecialchars($riga['nome']) ?></td>
                        <td><?= number_format($riga['prezzo'], 2, ',', '') ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<p><a href="dashboard.php">Torna alla dashboard</a></p>
</body>
</html>
