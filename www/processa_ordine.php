<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$pdo->exec("SET search_path = develop");

if (empty($_POST['negozio']) || !isset($_POST['quantita']) || !is_array($_POST['quantita'])) {
    die("Dati non validi.");
}

$negozio = $_POST['negozio'];
$quantita_inserite = $_POST['quantita'];
$prodotti = [];

foreach ($quantita_inserite as $prodotto_id => $quantita) {
    $quantita = (int)$quantita;
    if ($quantita > 0) {
        $prodotti[] = [
            'prodotto' => $prodotto_id,
            'quantita' => $quantita
        ];
    }
}

if (empty($prodotti)) {
    die("Nessun prodotto selezionato.");
}

try {
    $json = json_encode($prodotti);

    $stmt = $pdo->prepare("SELECT develop.inserisci_ordine_ottimizzato(:negozio, :json)");
    $stmt->execute([
        ':negozio' => $negozio,
        ':json' => $json
    ]);

    echo "<p>Ordine inviato con successo per il negozio <strong>" . htmlspecialchars($negozio) . "</strong>.</p>";
    echo '<p><a href="rifornisci.php?deposito=' . urlencode($negozio) . '">Torna al negozio</a></p>';
    echo '<p><a href="dashboard.php">Torna alla dashboard</a></p>';

} catch (PDOException $e) {
    echo "<p><strong>Errore durante l'invio dell'ordine:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
    echo '<p><a href="rifornisci.php?deposito=' . urlencode($negozio) . '">Riprova</a></p>';
}
?>
