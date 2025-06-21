<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true || $_SESSION['user_role'] !== 'cliente') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$pdo->exec("SET search_path = develop");

try {
    $stmt = $pdo->prepare("SELECT codice_fiscale FROM clienti WHERE login = :email");
    $stmt->execute([':email' => $_SESSION['user_email']]);
    $cliente = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$cliente) {
        die("Cliente non trovato.");
    }
    $cf_cliente = $cliente['codice_fiscale'];
} catch (PDOException $e) {
    die("Errore DB: " . htmlspecialchars($e->getMessage()));
}

// Ricevo dati POST
$deposito = $_POST['deposito'] ?? '';
$quantita = $_POST['quantita'] ?? [];
$sconto = $_POST['sconto'] ?? '0';

// Validazioni base
if (empty($deposito)) {
    die("Errore: negozio non selezionato.");
}

if (!is_array($quantita) || count($quantita) === 0) {
    die("Errore: nessun prodotto selezionato.");
}

$prodotti_acquisto = [];

foreach ($quantita as $codice_prodotto => $qta) {
    $qta = (int)$qta;
    if ($qta > 0) {
        $prodotti_acquisto[] = [
            'prodotto' => $codice_prodotto,
            'quantita' => $qta
        ];
    }
}

if (empty($prodotti_acquisto)) {
    die("Errore: non è stata selezionata alcuna quantità valida.");
}

try {
    $stmt = $pdo->prepare("SELECT develop.inserisci_fattura_con_sconto_json(:cf, :deposito, :prodotti_json::jsonb, :sconto::numeric)");
    $stmt->execute([
        ':cf' => $cf_cliente,
        ':deposito' => $deposito,
        ':prodotti_json' => json_encode($prodotti_acquisto),
        ':sconto' => (int)$sconto
    ]);

    $id_fattura = $stmt->fetchColumn();

    echo "<p>Acquisto completato con successo. Numero fattura: <strong>" . htmlspecialchars($id_fattura) . "</strong></p>";
    echo '<p><a href="acquista.php">Torna agli acquisti</a></p>';

} catch (PDOException $e) {
    echo "<p>Errore durante l'acquisto: " . htmlspecialchars($e->getMessage()) . "</p>";
    echo '<p><a href="acquista.php">Riprova</a></p>';
}
