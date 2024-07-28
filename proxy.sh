#!/bin/bash

print_blue() {
    echo -e "\033[34m$1\033[0m"
}

print_red() {
    echo -e "\033[31m$1\033[0m"
}

print_green() {
    echo -e "\033[32m$1\033[0m"
}

print_pink() {
    echo -e "\033[95m$1\033[0m"
}

prompt_for_input() {
    read -p "$1" input
    echo $input
}

echo "Installing dependencies..."
npm install --save-dev hardhat
npm install dotenv
npm install @swisstronik/utils
npm install @openzeppelin/contracts
echo "Installation completed."

print_blue "Installing Hardhat and necessary dependencies..."
echo
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
echo

print_blue "Removing default package.json file..."
echo
rm package.json
echo

print_blue "Creating package.json file again..."
echo
cat <<EOL > package.json
{
  "name": "hardhat-project",
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^3.0.0",
    "hardhat": "^2.17.1"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0",
    "@swisstronik/utils": "^1.2.1"
  }
}
EOL

print_blue "Initializing Hardhat project..."
npx hardhat
echo
print_blue "Removing the default Hardhat configuration file..."
echo
rm hardhat.config.js
echo
read -p "Enter your wallet private key: " PRIVATE_KEY

if [[ $PRIVATE_KEY != 0x* ]]; then
  PRIVATE_KEY="0x$PRIVATE_KEY"
fi

cat <<EOL > hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.20",
  networks: {
    swisstronik: {
      url: "https://json-rpc.testnet.swisstronik.com/",
      accounts: ["$PRIVATE_KEY"],
    },
  },
};
EOL

print_blue "Hardhat configuration file has been updated."
echo

echo "Creating Hello_swtr.sol contract..."
mkdir -p contracts
cat <<EOL > contracts/Hello_swtr.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Swisstronik {
    string private message;

    function initialize(string memory _message) public {
        message = _message;
    }

    function setMessage(string memory _message) public {
        message = _message;
    }

    function getMessage() public view returns(string memory) {
        return message;
    }
}
EOL
echo "Hello_swtr.sol contract created."

echo "Compiling the contract..."
npx hardhat compile
echo "Contract compiled."

echo "Creating deploy.js script..."
mkdir -p scripts
cat <<EOL > scripts/deploy.js
const fs = require("fs");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const Swisstronik = await ethers.getContractFactory('Swisstronik');
  const swisstronik = await Swisstronik.deploy();
  await swisstronik.waitForDeployment(); 
  console.log('Non-proxy Swisstronik deployed to:', swisstronik.target);
  fs.writeFileSync("contract.txt", swisstronik.target);

  console.log(\`Deployment transaction hash: https://explorer-evm.testnet.swisstronik.com/address/\${swisstronik.target}\`);

  console.log('');
  
  const upgradedSwisstronik = await upgrades.deployProxy(Swisstronik, ['Hello Swisstronik from Happy Cuan Airdrop!!'], { kind: 'transparent' });
  await upgradedSwisstronik.waitForDeployment(); 
  console.log('Proxy Swisstronik deployed to:', upgradedSwisstronik.target);
  fs.writeFileSync("proxiedContract.txt", upgradedSwisstronik.target);

  console.log(\`Deployment transaction hash: https://explorer-evm.testnet.swisstronik.com/address/\${upgradedSwisstronik.target}\`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOL
echo "deploy.js script created."

echo "Deploying the contract..."
npx hardhat run scripts/deploy.js --network swisstronik
echo "Contract deployed."

echo "Creating setMessage.js script..."
cat <<EOL > scripts/setMessage.js
const hre = require("hardhat");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");
const fs = require("fs");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpclink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpclink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("proxiedContract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("Swisstronik");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "setMessage";
  const messageToSet = "Hello Swisstronik from Happy Cuan Airdrop!!";
  const setMessageTx = await sendShieldedTransaction(signer, contractAddress, contract.interface.encodeFunctionData(functionName, [messageToSet]), 0);
  await setMessageTx.wait();
  console.log("Transaction Receipt: ", setMessageTx);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "setMessage.js script created."

echo "Running setMessage.js..."
npx hardhat run scripts/setMessage.js --network swisstronik
echo "Message set."

echo "Creating getMessage.js script..."
cat <<EOL > scripts/getMessage.js
const hre = require("hardhat");
const { encryptDataField, decryptNodeResponse } = require("@swisstronik/utils");
const fs = require("fs");

const sendShieldedQuery = async (provider, destination, data) => {
  const rpclink = hre.network.config.url;
  const [encryptedData, usedEncryptedKey] = await encryptDataField(rpclink, data);
  const response = await provider.call({
    to: destination,
    data: encryptedData,
  });
  return await decryptNodeResponse(rpclink, response, usedEncryptedKey);
};

async function main() {
  const contractAddress = fs.readFileSync("proxiedContract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("Swisstronik");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "getMessage";
  const responseMessage = await sendShieldedQuery(signer.provider, contractAddress, contract.interface.encodeFunctionData(functionName));
  console.log("Decoded response:", contract.interface.decodeFunctionResult(functionName, responseMessage)[0]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
echo "getMessage.js script created."

echo "Running getMessage.js..."
npx hardhat run scripts/getMessage.js --network swisstronik
echo "Message retrieved."

echo
print_green "Copy the above Tx URL and save it somewhere, you need to submit it on Testnet page"
echo
sed -i 's/0x[0-9a-fA-F]*,\?\s*//g' hardhat.config.js
echo
print_blue "PRIVATE_KEY has been removed from hardhat.config.js."
echo
print_blue "Pushing these files to your github Repo link"
git add . && git commit -m "Initial commit" && git push origin main
echo

echo -e ' ##   ##   ######  #####    #####    #######  ##    ## '
echo -e ' ##   ##     ##    ##  ##   ##  ##   ##       ###   ## '
echo -e ' ##   ##     ##    ##   ##  ##   ##  ##       ## #  ## '
echo -e ' #######     ##    ##   ##  ##   ##  #####    ##  # ## '
echo -e ' ##   ##     ##    ##   ##  ##   ##  ##       ##   ### '
echo -e ' ##   ##     ##    ##  ##   ##  ##   ##       ##    ## '
echo -e ' ##   ##   ######  #####    #####    #######  ##    ## '
                                                      
echo -e '        #####     #######  ##     ## '
echo -e '       ##   ##    ##       ###   ### ' 
echo -e '       ##         ##       ## # # ## '  
echo -e '       ##  #####  #####    ##  #  ## '  
echo -e '       ##   ## #  ##       ##     ## '  
echo -e '       ##   ## #  ##       ##     ## '  
echo -e '        #####     #######  ##     ## '

echo -e ' Wellcome To Hidden Gem Node Running Installation Guide '

echo -e '\e[0m'
