<?php

function get_user_role(PDO $pdo, string $login): UserRole
{
    $pdo->exec("SET search_path = develop");

    $stmt = $pdo->prepare("SELECT 1 FROM develop.clienti WHERE login = :login");
    $stmt->execute(['login' => $login]);
    if ($stmt->fetch()) {
        return UserRole::Cliente;
    }

    $stmt = $pdo->prepare("SELECT 1 FROM develop.manager WHERE login = :login");
    $stmt->execute(['login' => $login]);
    if ($stmt->fetch()) {
        return UserRole::Manager;
    }

    return UserRole::Unknown;
}


enum UserRole: string
{
    case Cliente = 'cliente';
    case Manager = 'manager';
    case Unknown = 'unknown';

    public function isKnown(): bool
    {
        return $this !== self::Unknown;
    }
}

