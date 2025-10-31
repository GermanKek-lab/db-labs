set search_path to lab01, public;

alter table customer_profile
    add foreign key (customer_id) references customer(id) on delete cascade;

alter table customer_address
    add foreign key (customer_id) references customer(id) on delete cascade,
    add foreign key (address_id) references address(id) on delete cascade;

alter table branch
    add foreign key (address_id) references  address(id);

alter table employee
    add foreign key (branch_id) references branch(id) on delete restrict;


alter table exchange_rate
    add foreign key (base_code)  references currency(code) on delete restrict,
    add foreign key (quote_code) references currency(code) on delete restrict;


alter table account
    add foreign key (customer_id) references customer(id) on delete restrict,
    add foreign key (product_id) references product(id) on delete restrict,
    add foreign key (currency_code) references currency(code) on delete restrict;

alter table card
    add foreign key (account_id) references account(id) on delete cascade;

alter table txn
    add foreign key (account_id) references account(id) on delete cascade,
    add foreign key (currency_code) references currency(code) on delete restrict;

alter table loan
    add foreign key (customer_id) references customer(id) on delete restrict,
    add foreign key (product_id)  references product(id)  on delete restrict,
    add foreign key (currency_code) references currency(code) on delete restrict,
    add foreign key (linked_account_id) references account(id) on delete set null;
