import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fund_tracker/models/category.dart';
import 'package:fund_tracker/models/transaction.dart';
import 'package:fund_tracker/pages/categories/categoriesRegistry.dart';
import 'package:fund_tracker/services/databaseWrapper.dart';
import 'package:fund_tracker/services/sync.dart';
import 'package:fund_tracker/shared/library.dart';
import 'package:fund_tracker/shared/styles.dart';
import 'package:fund_tracker/shared/widgets.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class TransactionForm extends StatefulWidget {
  final Transaction tx;

  TransactionForm(this.tx);

  @override
  _TransactionFormState createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();

  DateTime _date;
  bool _isExpense;
  String _payee;
  double _amount;
  String _category;

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final _user = Provider.of<FirebaseUser>(context);
    final isEditMode = widget.tx.tid != null;
    final List<Category> _categories = Provider.of<List<Category>>(context);
    final List<Category> _enabledCategories = _categories != null
        ? _categories.where((category) => category.enabled).toList()
        : [];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Transaction' : 'Add Transaction'),
        actions: isEditMode
            ? <Widget>[
                deleteIcon(
                  context,
                  'transaction',
                  () async => await DatabaseWrapper(_user.uid)
                      .deleteTransactions([widget.tx]),
                  () => SyncService(_user.uid).syncTransactions(),
                ),
              ]
            : null,
      ),
      body: (_enabledCategories != null &&
              _enabledCategories.isNotEmpty &&
              !isLoading)
          ? Container(
              padding: formPadding,
              child: Form(
                key: _formKey,
                child: ListView(
                  children: <Widget>[
                    SizedBox(height: 20.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Expanded(
                          child: FlatButton(
                            padding: EdgeInsets.all(15.0),
                            color: (_isExpense ?? widget.tx.isExpense)
                                ? Colors.grey[100]
                                : Theme.of(context).primaryColor,
                            child: Text(
                              'Income',
                              style: TextStyle(
                                  fontWeight:
                                      (_isExpense ?? widget.tx.isExpense)
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                  color: (_isExpense ?? widget.tx.isExpense)
                                      ? Colors.black
                                      : Colors.white),
                            ),
                            onPressed: () => setState(() => _isExpense = false),
                          ),
                        ),
                        Expanded(
                          child: FlatButton(
                            padding: EdgeInsets.all(15.0),
                            color: (_isExpense ?? widget.tx.isExpense)
                                ? Theme.of(context).primaryColor
                                : Colors.grey[100],
                            child: Text(
                              'Expense',
                              style: TextStyle(
                                fontWeight: (_isExpense ?? widget.tx.isExpense)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: (_isExpense ?? widget.tx.isExpense)
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            onPressed: () => setState(() => _isExpense = true),
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 20.0),
                    FlatButton(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(getDateStr(_date ?? widget.tx.date)),
                          Icon(Icons.date_range),
                        ],
                      ),
                      onPressed: () async {
                        DateTime date = await openDatePicker(context);
                        if (date != null) {
                          setState(() => _date = date);
                        }
                      },
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      initialValue: widget.tx.payee,
                      autovalidate: _payee != null,
                      validator: (val) {
                        if (val.isEmpty) {
                          return 'Enter a payee or a note.';
                        } else if (val.length > 30) {
                          return 'Max 30 characters.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Payee',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (val) {
                        setState(() => _payee = val);
                      },
                    ),
                    SizedBox(height: 20.0),
                    TextFormField(
                      initialValue: widget.tx.amount != null
                          ? widget.tx.amount.toStringAsFixed(2)
                          : '',
                      autovalidate: _amount != null,
                      validator: (val) {
                        if (val.isEmpty) {
                          return 'Please enter an amount.';
                        }
                        if (val.indexOf('.') > 0 &&
                            val.split('.')[1].length > 2) {
                          return 'At most 2 decimal places allowed.';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Amount',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setState(() => _amount = double.parse(val));
                      },
                    ),
                    SizedBox(height: 20.0),
                    Center(
                      child: DropdownButton<String>(
                        items: _enabledCategories.map((category) {
                              return DropdownMenuItem(
                                value: category.name,
                                child: Row(children: <Widget>[
                                  Icon(
                                    IconData(
                                      category.icon,
                                      fontFamily: 'MaterialIcons',
                                    ),
                                    color: categoriesRegistry.singleWhere(
                                        (cat) =>
                                            cat['name'] ==
                                            category.name)['color'],
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    category.name,
                                  ),
                                ]),
                              );
                            }).toList() +
                            (_enabledCategories.any((category) =>
                                    widget.tx.category == null ||
                                    category.name == widget.tx.category)
                                ? []
                                : [
                                    DropdownMenuItem(
                                      value: widget.tx.category,
                                      child: Row(children: <Widget>[
                                        Icon(
                                            IconData(
                                              _categories
                                                  .singleWhere((cat) =>
                                                      cat.name ==
                                                      widget.tx.category)
                                                  .icon,
                                              fontFamily: 'MaterialIcons',
                                            ),
                                            color: categoriesRegistry
                                                .singleWhere((cat) =>
                                                    cat['name'] ==
                                                    widget
                                                        .tx.category)['color']),
                                        SizedBox(width: 10),
                                        Text(
                                          widget.tx.category,
                                        ),
                                      ]),
                                    )
                                  ]),
                        onChanged: (val) {
                          setState(() => _category = val);
                        },
                        value: _category ??
                            widget.tx.category ??
                            _enabledCategories.first.name,
                        isExpanded: true,
                      ),
                    ),
                    SizedBox(height: 20.0),
                    RaisedButton(
                      color: Theme.of(context).primaryColor,
                      child: Text(
                        isEditMode ? 'Save' : 'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState.validate()) {
                          Transaction tx = Transaction(
                            tid: widget.tx.tid ?? Uuid().v1(),
                            date: _date ?? widget.tx.date,
                            isExpense: _isExpense ?? widget.tx.isExpense,
                            payee: _payee ?? widget.tx.payee,
                            amount: _amount ?? widget.tx.amount,
                            category: _category ??
                                widget.tx.category ??
                                _enabledCategories.first.name,
                            uid: _user.uid,
                          );
                          setState(() => isLoading = true);
                          isEditMode
                              ? await DatabaseWrapper(_user.uid)
                                  .updateTransactions([tx])
                              : await DatabaseWrapper(_user.uid)
                                  .addTransactions([tx]);
                          SyncService(_user.uid).syncTransactions();
                          Navigator.pop(context);
                        }
                      },
                    )
                  ],
                ),
              ),
            )
          : Loader(),
    );
  }
}
