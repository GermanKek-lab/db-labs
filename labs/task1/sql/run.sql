CREATE SCHEMA IF NOT EXISTS task1;
SET search_path TO task1, public;

CREATE TABLE IF NOT EXISTS members (
    id   text PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE IF NOT EXISTS authors (
    id   bigserial PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE IF NOT EXISTS books (
    id        text PRIMARY KEY,
    title     text NOT NULL,
    author_id bigint NOT NULL REFERENCES authors(id)
);

CREATE TABLE IF NOT EXISTS loans (
    member_id   text NOT NULL REFERENCES members(id),
    book_id     text NOT NULL REFERENCES books(id),
    loan_date   date NOT NULL,
    return_date date,
    PRIMARY KEY (member_id, book_id, loan_date)
);