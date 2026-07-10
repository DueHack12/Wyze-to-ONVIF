// Patched copy of src/config-tools.js from dlo747/RTSP-to-ONVIF-Unifi-Protect,
// pinned at commit fcdbcf9f624bd00c874bc00b6b5a07a77ec4f536. It is COPYed over
// the upstream file at build time (see Dockerfile). If you bump UPSTREAM_SHA in
// the Dockerfile, re-check this patch against the new upstream file.
//
// Only change vs. upstream: when a camera config provides an `ipv4` (CIDR)
// field, the virtual interface is given that address statically instead of
// requesting one over DHCP. This backs the add-on's per-camera `ip` option, so
// cameras can keep a fixed address that survives reinstalls. With no `ipv4`
// field the behaviour is unchanged (dhclient), matching upstream.

const YAML = require('yaml');
const fs = require('fs');
const { execSync } = require('child_process');

const { getIp4FromMac, generateUUIDv4, generateNetworkMac } = require('./net-tools')


function readConfig(logger, configFile) {

    let configData;
    try {
        configData = fs.readFileSync(configFile, 'utf8');
    } catch (error) {
        if (error.code === 'ENOENT') {
            logger.info(`File not found: ${configFile}`);
            exit(-1);
        }
        throw error;
    }

    let config;
    try {
        config = YAML.parse(configData);
    } catch (error) {
        logger.info('Failed to read config, invalid yaml syntax.')
        exit(-1);
    }

    return config;
}

function sleep(seconds){
    const spawnSync = require('child_process').spawnSync;
    var sleep = spawnSync('sleep', [seconds]);
}

function readAndCheckConfig(logger, configFile) {


    let config = readConfig(logger, configFile);

    let isSaveRequired = false;
    let proxyCounter = 0;
    for (let onvifConfig of config.onvif) {

        //Generate a V4 UUID
        if (!onvifConfig.uuid) {
            let newId = generateUUIDv4();
            logger.info(`CONFIG: UUIDv4 - ${newId}`);
            onvifConfig.uuid = newId;
            isSaveRequired = true;
        }

        // Generate Network MAC for Unicast LAA Prefix
        if (!onvifConfig.mac) {
            let newId = generateNetworkMac();
            logger.info(`CONFIG: MAC - ${newId}`);
            onvifConfig.mac = newId;
            isSaveRequired = true;
        }

        if (!getIp4FromMac(logger, onvifConfig.mac)) {
            const vlanName = `rtsp2onvif_${proxyCounter}`;

            logger.info(`NET_CONF: ADD - ${vlanName} MAC: ${onvifConfig.mac}`);
            try {
                const stdout = execSync(`ip link add ${vlanName} link ${onvifConfig.dev} address ${onvifConfig.mac} type macvlan mode bridge`);
                logger.debug(stdout);
            } catch (error) {
                logger.debug(error.message);
            }

            if (onvifConfig.ipv4) {
                // PATCH: assign a static IPv4 (CIDR) instead of using DHCP.
                logger.info(`NET_CONF: STATIC - ${vlanName} IPv4 ${onvifConfig.ipv4}`);
                try {
                    const stdout = execSync(`ip addr add ${onvifConfig.ipv4} dev ${vlanName}`);
                    logger.debug(stdout);
                } catch (error) {
                    logger.debug(error.message);
                }
                try {
                    const stdout = execSync(`ip link set ${vlanName} up`);
                    logger.debug(stdout);
                } catch (error) {
                    logger.debug(error.message);
                }
            } else {
                logger.info(`NET_CONF: DHCP - ${vlanName}`);
                try {
                    const stdout = execSync(`dhclient ${vlanName}`);
                    logger.debug(stdout);
                } catch (error) {
                    logger.debug(error.message);
                }
            }
        }
        proxyCounter++
    }

    if (isSaveRequired) {
        writeConfig(logger, configFile, config);
        sleep(2);
    }

    return config;
}

function writeConfig(logger, configFile, config) {
    const yamlString = YAML.stringify(config);

    fs.writeFileSync(configFile, yamlString, 'utf8');
    logger.info(`CONFIG: Updated ${configFile}`);
}

module.exports = {
    readAndCheckConfig
}
