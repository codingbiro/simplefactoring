/* eslint-disable no-plusplus */
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
    } else if (!isTimestampUndefined(array[i][field])) {
      counter++;
    }
  }
  return counter;
}

function getRoundedBalance(balance) {
  return Math.ceil(balance / web3.utils.toWei('1', 'ether')) * web3.utils.toWei('1', 'ether');
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
      // .then(() => {
      //   return sfInstance.getOverDueCount({ from: accounts[0] });
      // })
      // .then((overdueInvoiceCount) => {
      //   assert.equal(0, overdueInvoiceCount, 'Error with counting overdue Invoices');
      // })
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
    let payeeBalance = 0;
    let payerBalance = 0;
    return (
      SimpleFactoring.deployed()
        .then((instance) => {
          sfInstance = instance;
          return sfInstance.createInvoice(timestamp, accounts[1], web3.utils.toWei('1', 'ether'), {
            from: accounts[0],
          });
        })
        .then(() => {
          return sfInstance.getUnsettledInvoices({ from: accounts[0] });
        })
        .then((unsettledInvoices) => {
          assert(Array.isArray(unsettledInvoices), 'Error with unsettled Invoices: payee');
          assert.equal(
            0,
            getArrayLength(unsettledInvoices, 'invoice', 'dueDate'),
            'Error with unsettled Invoices: payee',
          );
        })
        // Saving payee and payer balance before payment
        .then(() => {
          return web3.eth.getBalance(accounts[0]);
        })
        .then((_payeeBalance) => {
          payeeBalance = _payeeBalance;
          return web3.eth.getBalance(accounts[1]);
        })
        .then((_payerBalance) => {
          payerBalance = _payerBalance;
          return sfInstance.getUnsettledInvoices({ from: accounts[1] });
        })
        .then((unsettledInvoices) => {
          assert(Array.isArray(unsettledInvoices), 'Error with unsettled Invoices: payer');
          assert.equal(
            1,
            getArrayLength(unsettledInvoices, 'invoice', 'dueDate'),
            'Error with unsettled Invoices: payer',
          );
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
        // The ether should be transferred from payer to payee
        .then((_payerBalance) => {
          assert.equal(
            getRoundedBalance(_payerBalance),
            getRoundedBalance(payerBalance) - parseInt(web3.utils.toWei('1', 'ether'), 10),
            'Error with paying Invoices: payer',
          );
          return web3.eth.getBalance(accounts[0]);
        })
        .then((_payeeBalance) => {
          assert.equal(
            getRoundedBalance(_payeeBalance),
            getRoundedBalance(payeeBalance) + parseInt(web3.utils.toWei('1', 'ether'), 10),
            'Error with paying Invoices: payee',
          );
        })
    );
  });

  // Test case 4
  it('Test market: selling and buying invoices', () => {
    let payeeBalance = 0;
    let payerBalance = 0;
    return (
      SimpleFactoring.deployed()
        // The invoice to be sold
        .then((instance) => {
          sfInstance = instance;
          return sfInstance.createInvoice(timestamp, accounts[1], web3.utils.toWei('10', 'ether'), {
            from: accounts[0],
          });
        })
        .then(() => {
          return sfInstance.getInvoices({ from: accounts[0] });
        })
        // Putting up the invoice for sale
        .then((invoices) => {
          const validInvoices = invoices.filter((i) => !isTimestampUndefined(i.dueDate) && !i.settled);
          assert(validInvoices.length === 1, 'Error with invoice creation');
          return sfInstance.sellInvoice(validInvoices[0].index, web3.utils.toWei('9', 'ether'), { from: accounts[0] });
        })
        // Saving payee and payer balance before purchase
        .then(() => {
          return web3.eth.getBalance(accounts[0]);
        })
        .then((_payeeBalance) => {
          payeeBalance = _payeeBalance;
          return web3.eth.getBalance(accounts[2]);
        })
        // Listing invoices available for purchase
        .then((_payerBalance) => {
          payerBalance = _payerBalance;
          return sfInstance.getOffers();
        })
        .then((offers) => {
          assert(Array.isArray(offers), 'Error with offers');
          assert.equal(1, getArrayLength(offers, 'invoice', 'dueDate'), 'Error with offers');
          return offers;
        })
        // Buying the invoice
        .then((offers) => {
          const offer = offers[0];
          return sfInstance.buyInvoice(offer.index, { from: accounts[2], value: offer.invoice.resellPrice });
        })
        // The bought offer should be removed from the offers
        .then(() => {
          return sfInstance.getOffers();
        })
        .then((offers) => {
          assert(Array.isArray(offers), 'Error with purchasing invoices');
          assert.equal(0, getArrayLength(offers, 'invoice', 'dueDate'), 'Error with purchasing invoices');
        })
        // The invoice should be removed from seller
        .then(() => {
          return sfInstance.getInvoices({ from: accounts[0] });
        })
        .then((invoices) => {
          const validInvoices = invoices.filter((i) => !isTimestampUndefined(i.dueDate) && !i.settled);
          assert(validInvoices.length === 0, 'Error with invoice selling');
        })
        // The invoice should be added for the buyer
        .then(() => {
          return sfInstance.getInvoices({ from: accounts[2] });
        })
        .then((invoices) => {
          assert(Array.isArray(invoices), 'Error with purchasing invoices');
          assert.equal(1, getArrayLength(invoices, 'dueDate', undefined), 'Error with purchasing invoices');
        })
        // The ether should be transferred from payer to payee
        .then(() => {
          return web3.eth.getBalance(accounts[2]);
        })
        .then((_payerBalance) => {
          assert.equal(
            getRoundedBalance(_payerBalance),
            getRoundedBalance(payerBalance) - parseInt(web3.utils.toWei('9', 'ether'), 10),
            'Error with buying Invoices: payer',
          );
          return web3.eth.getBalance(accounts[0]);
        })
        .then((_payeeBalance) => {
          assert.equal(
            getRoundedBalance(_payeeBalance),
            getRoundedBalance(payeeBalance) + parseInt(web3.utils.toWei('9', 'ether'), 10),
            'Error with buying Invoices: payee',
          );
        })
    );
  });
});
