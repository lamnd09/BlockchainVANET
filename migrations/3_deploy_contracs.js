var Ownable = artifacts.require("Ownable");
var Arg = "User Register";
module.exports = deployer => {
    deployer.deploy(Ownable, Arg);
};