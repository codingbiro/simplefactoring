var SimpleFactoring = artifacts.require("SimpleFactoring");

var timestamp = 1633845600; // 2021.10.10. 8:00

function getArrayLength(array, field) {
    if (!Array.isArray(array)) return -1;
    var counter = 0;
    for (var i = 0; i < array.length; i++) {
        if (array[i][field] != '0') {
            counter++;
        }
    }
    return counter;
}

contract('SimpleFactoring', function(accounts) {
    var sfInstance;

    // Test case 1
    it("Test initial commission", function() {
        return SimpleFactoring.deployed().then(function(instance) {
            sf = instance;
            return sf.commission();
        }).then(function(x) {
            assert.equal(2, x, "Wrong initial commission");
        });
    });

     // Test case 2
     it("Test invoice creation, listing, splitting and merging", function() {
        return SimpleFactoring.deployed().then(function(instance) {
            sfInstance = instance;
            return sfInstance.createInvoice(timestamp, accounts[1], web3.utils.toWei('1', 'ether'), { from: accounts[0] });
        })
        .then(function() {
            return sfInstance.getInvoices({ from: accounts[0] });
         })
        .then(function(invoices) {
            assert(Array.isArray(invoices), "Error with Invoices");
            assert.equal(1, getArrayLength(invoices, "dueDate"), "Error with Invoices");
        })
        .then(function() {
             return sfInstance.getOverDueCount({ from: accounts[0] });
         })
        .then(function(overdueInvoiceCount) {
            assert.equal(0, overdueInvoiceCount, "Error with counting overdue Invoices");
        })
        .then(function() {
            return sfInstance.getInvoices({ from: accounts[0] });
         })
        .then(function(invoices) {
            return sfInstance.splitInvoice(invoices[0].index, 2, { from: accounts[0] });
        })
        .then(function() {
            return sfInstance.getInvoices({ from: accounts[0] });
        })
        .then(function(invoices) {
            assert(Array.isArray(invoices), "Error with Invoice splitting");
            assert.equal(2, getArrayLength(invoices, "dueDate"), "Error with Invoice splitting");
            return invoices;
        })
        .then(function(invoices) {
             return sfInstance.mergeInvoices([invoices[1].index, invoices[2].index], { from: accounts[0] });
         })
        .then(function() {
            return sfInstance.getInvoices({ from: accounts[0] });
        })
        .then(function(invoices) {            
            assert(Array.isArray(invoices), "Error with Invoice merging");
            assert.equal(1, getArrayLength(invoices, "dueDate"), "Error with Invoice merging");
        })
    });
});