const SimpleFactoring = artifacts.require('SimpleFactoring');

const timestamp = 1633845600; // 2021.10.10. 8:00

function isTimestampUndefined(field) {
  return field === '0';
}

function getArrayLength(array, field, field2) {
  if (!Array.isArray(array)) return -1;
  let counter = 0;
  for (let i = 0; i < array.length; i++) {
    if (field2) {
      if (!isTimestampUndefined(array[i][field][field2])) {
        counter++;
      }
    } else {
      if (!isTimestampUndefined(array[i][field])) {
        counter++;
      }
    }
  }
  return counter;
}

contract('SimpleFactoring', (accounts) => {
  let sfInstance;

  // Test case 1
  it('Test initial commission', () => {
    return SimpleFactoring.deployed()
      .then((instance) => {
        sfInstance = instance;
        return sfInstance.commission();
      })
      .then((commission) => {
        assert.equal(2, commission, 'Wrong initial commission');
      });
  });

  // Test case 2
  it('Test invoice creation, listing, splitting/merging and deleting', () => {
    return SimpleFactoring.deployed()
      .then((instance) => {
        sfInstance = instance;
        return sfInstance.createInvoice(timestamp, accounts[1], web3.utils.toWei('1', 'ether'), { from: accounts[0] });
      })
      .then(() => {
        return sfInstance.getInvoices({ from: accounts[0] });
      })
      .then((invoices) => {
        assert(Array.isArray(invoices), 'Error with Invoices');
        assert.equal(1, getArrayLength(invoices, 'dueDate', undefined), 'Error with Invoices');
      })
      .then(() => {
        return sfInstance.getOverDueCount({ from: accounts[0] });
      })
      .then((overdueInvoiceCount) => {
        assert.equal(0, overdueInvoiceCount, 'Error with counting overdue Invoices');
      })
      .then(() => {
        return sfInstance.getInvoices({ from: accounts[0] });
      })
      .then((invoices) => {
        return sfInstance.splitInvoice(invoices[0].index, 2, { from: accounts[0] });
      })
      .then(() => {
        return sfInstance.getInvoices({ from: accounts[0] });
      })
      .then((invoices) => {
        assert(Array.isArray(invoices), 'Error with Invoice splitting');
        assert.equal(2, getArrayLength(invoices, 'dueDate', undefined), 'Error with Invoice splitting');
        return invoices;
      })
      .then((invoices) => {
        return sfInstance.mergeInvoices([invoices[1].index, invoices[2].index], { from: accounts[0] });
      })
      .then(() => {
        return sfInstance.getInvoices({ from: accounts[0] });
      })
      .then((invoices) => {
        assert(Array.isArray(invoices), 'Error with Invoice merging');
        assert.equal(1, getArrayLength(invoices, 'dueDate', undefined), 'Error with Invoice merging');
        return invoices;
      })
      .then((invoices) => {
        const validInvoices = invoices.filter((i) => !isTimestampUndefined(i.dueDate));
        assert(validInvoices.length > 0, 'Error with Invoice split/merge');
        return sfInstance.deleteInvoice(validInvoices[0].index, { from: accounts[0] });
      })
      .then(() => {
        return sfInstance.getInvoices({ from: accounts[0] });
      })
      .then((invoices) => {
        assert(Array.isArray(invoices), 'Error with Invoice deletion');
        assert.equal(0, getArrayLength(invoices, 'dueDate', undefined), 'Error with Invoice deletion');
      });
  });

  // Test case 3
  it('Test invoices for payer: listing and paying', () => {
    return SimpleFactoring.deployed()
      .then((instance) => {
        sfInstance = instance;
        return sfInstance.createInvoice(timestamp, accounts[1], web3.utils.toWei('1', 'ether'), { from: accounts[0] });
      })
      .then(() => {
        return sfInstance.getUnsettledInvoices({ from: accounts[0] });
      })
      .then((unsettledInvoices) => {
        assert(Array.isArray(unsettledInvoices), 'Error with unsettled Invoices: payee');
        assert.equal(0, getArrayLength(unsettledInvoices, 'invoice', 'dueDate'), 'Error with unsettled Invoices: payee');
      })
      .then(() => {
        return sfInstance.getUnsettledInvoices({ from: accounts[1] });
      })
      .then((unsettledInvoices) => {
        assert(Array.isArray(unsettledInvoices), 'Error with unsettled Invoices: payer');
        assert.equal(1, getArrayLength(unsettledInvoices, 'invoice', 'dueDate'), 'Error with unsettled Invoices: payer');
        return unsettledInvoices;
      })
      .then((unsettledInvoices) => {
        return sfInstance.payInvoice(unsettledInvoices[0].invoice.index, unsettledInvoices[0].beneficiary, {
          from: accounts[1],
          value: unsettledInvoices[0].invoice.total,
        });
      })
      .then(() => {
        return sfInstance.getUnsettledInvoices({ from: accounts[1] });
      })
      .then((unsettledInvoices) => {
        assert(Array.isArray(unsettledInvoices), 'Error with unsettled Invoices');
        assert.equal(0, getArrayLength(unsettledInvoices, 'invoice', 'dueDate'), 'Error with unsettled Invoices');
        return web3.eth.getBalance(accounts[1]);
      })
      .then((payerBalance) => {
        assert(web3.utils.toWei('99', 'ether') >= payerBalance, 'Error with paying Invoices: payer');
        return web3.eth.getBalance(accounts[0]);
      })
      .then((payeeBalance) => {
        assert(web3.utils.toWei('100', 'ether') < payeeBalance, 'Error with paying Invoices: payee');
      });
  });

  // TODO Market methods
});
