const GOPCreator = artifacts.require("./GOPCreator");
const Core = artifacts.require("./Core");

contract("GOPCreator", acc => {
  let instance, core;
  let owner = acc[1];
  let amount = web3.toWei(0.40, "ether");

  before("setup instance", async () => {
    instance = await GOPCreator.deployed();
    core = await Core.deployed();

    await core.setGOPCreator(instance.address, { from: owner });

    await instance.openBatch(1, { from: owner });

    await instance.createGOP(owner, "first hash", { value: amount }); // 0
  })

  it("should open a batch", async () => {
    await instance.createGOP(owner, "some hash", { value: amount }); // 1

    let remaining = await instance.horsesRemaining.call(1);

    assert.equal(remaining.toNumber(), 999);
  })

  it("should create correct horse based on open batch", async () => {
    await instance.closeBatch(1, { from: owner });
    await instance.openBatch(3, { from: owner });
    await instance.createGOP(owner, "some hash", { value: amount }); // 2

    let genotype = await core.getGenotype.call(2);
    let bloodline = await core.getBloodline.call(2);

    assert.equal(genotype.toNumber(), 3);
    assert.equal(web3.toUtf8(bloodline), "S");
  })

  it("should revert and not modify state", async () => {
    try {
      await instance.createGOP(owner, "some hash"); // 3
      assert.fail("Expected revert not received");
    } catch (err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }

    let genotype = await core.getGenotype.call(3);
    assert.equal(genotype.toNumber(), 0);
  })

  it("should close the batch once the number of horses available is 500", async () => {
    await instance.closeBatch(3, { from: owner });
    await instance.openBatch(1, { from: owner });

    for (let i = 2; i <= 500; i++) {
      await instance.createGOP(owner, "some hash", { value: amount });
    }

    try {
      await instance.createGOP(owner, "some hash", { value: amount }); // 3
      assert.fail("Expected revert not received");
    } catch (err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }

    let rem = await instance.horsesRemaining.call(1);
    assert.equal(rem.toNumber(), 500);
  })

  it("should allow to create more horses if the batch is open manually after reaching 500 horses", async () => {
    await instance.openBatch(1, { from: owner });
    await instance.createGOP(owner, "some hash", { value: amount });

    let rem = await instance.horsesRemaining.call(1);
    assert.equal(rem.toNumber(), 499);
  })

  it("should transfer the paid amount when a batch from 1 to 4 is open", async () => {
    let balance = await web3.eth.getBalance(owner);

    // Batch open <1>
    await instance.createGOP(acc[2], "some hash", { from: acc[2], value: amount });

    let newBalance = await web3.eth.getBalance(owner);

    let res = (newBalance > balance);

    assert(res);
  })
})