<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$pdo->exec("SET search_path = develop");

$negozi = [];
$prodotti = [];
$deposito_selezionato = $_GET['deposito'] ?? null;

try {
    $stmt = $pdo->query("SELECT id, orario_apertura, orario_chiusura FROM negozi WHERE attivo = true ORDER BY id");
    $negozi = $stmt->fetchAll();

    if ($deposito_selezionato) {
        $stmt = $pdo->prepare("
            SELECT p.id, p.nome, COALESCE(d.quantita, 0) AS quantita
            FROM prodotti p
            LEFT JOIN disponibilita d ON d.prodotto = p.id AND d.deposito = :deposito
            ORDER BY p.nome
        ");
        $stmt->execute([':deposito' => $deposito_selezionato]);
        $prodotti = $stmt->fetchAll();
    }
} catch (PDOException $e) {
    die("Errore database: " . htmlspecialchars($e->getMessage()));
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Rifornisci Negozio</title>
    <style>
        body {
            font-family: Arial, sans-serif;
        }
        .container {
            display: flex;
            margin-top: 20px;
            gap: 30px;
        }
        .selezione-negozio {
            min-width: 250px;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            max-width: 700px;
        }
        th, td {
            border: 1px solid #ccc;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #eee;
        }
        input[type="number"] {
            width: 60px;
        }
        button {
            margin-top: 15px;
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
        /* Contenitore scroll verticale */
        .table-wrapper {
            max-height: 400px;
            overflow-y: auto;
            border: 1px solid #ccc;
        }
    </style>
</head>
<body>
    <h1>Rifornisci un negozio</h1>

    <div class="container">
        <div class="selezione-negozio">
            <form method="GET" action="rifornisci.php">
                <label for="deposito"><strong>Seleziona negozio:</strong></label><br>
                <select name="deposito" id="deposito" onchange="this.form.submit()">
                    <option value="">-- Scegli un negozio --</option>
                    <?php foreach ($negozi as $negozio): ?>
                        <option value="<?= htmlspecialchars($negozio['id']) ?>"
                            <?= ($negozio['id'] === $deposito_selezionato) ? 'selected' : '' ?>>
                            <?= htmlspecialchars($negozio['id']) ?>
                            (<?= substr($negozio['orario_apertura'], 0, 5) ?> - <?= substr($negozio['orario_chiusura'], 0, 5) ?>)
                        </option>
                    <?php endforeach; ?>
                </select>
            </form>
        </div>

        <?php if ($deposito_selezionato): ?>
            <div class="tabella-prodotti">
                <form method="POST" action="processa_ordine.php">
                    <input type="hidden" name="negozio" value="<?= htmlspecialchars($deposito_selezionato) ?>">
                    <div class="table-wrapper">
                        <table>
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Nome</th>
                                    <th>Disponibilità</th>
                                    <th>Quantità da ordinare</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($prodotti as $p): ?>
                                    <tr>
                                        <td><?= htmlspecialchars($p['id']) ?></td>
                                        <td><?= htmlspecialchars($p['nome']) ?></td>
                                        <td><?= (int)$p['quantita'] ?></td>
                                        <td>
                                            <input type="number"
                                                   name="quantita[<?= htmlspecialchars($p['id']) ?>]"
                                                   min="0"
                                                   value="0">
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                    <button type="submit">Invia Ordine</button>
                </form>
            </div>
        <?php endif; ?>
    </div>

    <p><a href="dashboard.php">Torna alla dashboard</a></p>
</body>
</html>
