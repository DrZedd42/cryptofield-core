const Core = artifacts.require("./Core");

contract("StudService", acc => {
  let core, queryPrice;
  let owner = acc[1];
  let amount = web3.toWei(0.5, "ether");

  let seconds = { day3: 259200, day6: 518400 }

  before("setup instance", async () => {
    core = await Core.deployed();

    await core.createGOP(owner, "genesis male hash"); // 0
    await core.createGOP(owner, "female horse"); // 1
    await core.createGOP(owner, "male horse"); // 2

    queryPrice = await core.getQueryPrice.call();
  })

  it("should put the horse in stud", async () => {
    await core.putInStud(2, amount, seconds.day3, {from: owner, value: queryPrice});
    let studInfo = await core.studInfo.call(2);

    assert.equal(studInfo[0], true);
  })

  it("should be able to remove horse from stud", async () => {
    await core.removeFromStud(2, {from: owner});
    let studInfo = await core.studInfo.call(2);

    assert.equal(studInfo[0], false);
  })

  it("should revert when not the owner tries to put a horse in stud", async () => {
    try {
      await core.putInStud(2, amount, seconds.day6, {from: acc[2], value: queryPrice});
      assert.fail("Expected revert not received");
    } catch(err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }
  })

  it("should return valid data from stud", async () => {
    // Put the horse again in stud
    await core.putInStud(2, amount, seconds.day3, {from: owner, value: queryPrice});

    let studInfo = await core.studInfo.call(2);
    
    assert.equal(studInfo[0], true);
    assert.equal(studInfo[1], amount);

    // Remove from stud
    await core.removeFromStud(2, {from: owner});

    studInfo = await core.studInfo.call(2);

    assert.equal(studInfo[0], false);
    assert.equal(studInfo[1], 0);
  })

  it("should revert if we try to put a female horse into stud", async () => {
    try {
      await core.putInStud(1, amount, seconds.day6, {from: acc[2], value: queryPrice});
      assert.fail("Expected revert not received");
    } catch(err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }
  })

  it("should use a default value if a different time is sent", async () => {
    // We'll use a random value for the duration since only three values are allowed at the moment.
    await core.putInStud(2, amount, 123456, {from: owner, value: queryPrice});

    let studInfo = await core.studInfo.call(2);

    assert.equal(studInfo[2].toNumber(), 259200); // Default to three days.
  })
})