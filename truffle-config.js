const HDWalletProvider = require("truffle-hdwallet-provider");
const fs = require("fs");
module.exports = {
    networks: {
        development: {
            host: "127.0.0.1",
            port: 8545,
            network_id: "*"
        },
        loc_development_development: {
            network_id: "*",
            port: 7545,
            host: "127.0.0.1"
        }
    },
    compilers: {
        solc: {
            version: "0.7.4"
        }
    }
};