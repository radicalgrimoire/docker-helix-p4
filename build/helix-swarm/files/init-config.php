<?php

declare(strict_types=1);

$configPath = '/opt/perforce/swarm/data/config.php';
$required = ['P4D_PORT', 'SWARM_USER', 'SWARM_PASSWD'];
$values = [];
foreach ($required as $name) {
    $value = getenv($name);
    if ($value === false || $value === '') {
        fwrite(STDERR, "Cannot initialize Swarm: $name must be set.\n");
        exit(1);
    }
    $values[$name] = $value;
}

$hostname = getenv('SWARM_HOST');
if ($hostname === false || $hostname === '') {
    $hostname = 'localhost';
}

$config = [
    'environment' => ['hostname' => $hostname],
    'p4' => [
        'port' => $values['P4D_PORT'],
        'user' => $values['SWARM_USER'],
        'password' => $values['SWARM_PASSWD'],
    ],
];

umask(0077);
$temporaryPath = tempnam(dirname($configPath), '.config-');
if ($temporaryPath === false) {
    fwrite(STDERR, "Cannot create a temporary Swarm configuration.\n");
    exit(1);
}

try {
    $contents = "<?php\nreturn " . var_export($config, true) . ";\n";
    if (file_put_contents($temporaryPath, $contents, LOCK_EX) !== strlen($contents)) {
        throw new RuntimeException('Cannot write the Swarm configuration.');
    }
    if (!chmod($temporaryPath, 0600) || !chown($temporaryPath, 'www-data') ||
        !chgrp($temporaryPath, 'www-data')) {
        throw new RuntimeException('Cannot set Swarm configuration permissions.');
    }
    if (!link($temporaryPath, $configPath)) {
        throw new RuntimeException('Cannot create config.php; check whether it already exists.');
    }
} finally {
    if (!unlink($temporaryPath)) {
        fwrite(STDERR, "Cannot remove temporary Swarm configuration.\n");
        exit(1);
    }
}
