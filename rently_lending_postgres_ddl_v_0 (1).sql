Table legal_entity {
  id uuid [pk]
  name text
  registration_no text
  country_code char(2)
  functional_ccy char(3)
}

Table product {
  id uuid [pk]
  code text [unique]
  name text
  description text
}

Table party {
  id uuid [pk]
  kind text
  display_name text
  email text
  phone text
  external_ref text
  kyc_identifier text
}

Table party_role {
  id uuid [pk]
  party_id uuid [ref: > party.id]
  loan_id uuid [ref: > loan.id]
  role text
}

Table payment_instrument {
  id uuid [pk]
  party_id uuid [ref: > party.id]
  instrument_type text
  currency_code char(3)
  bank_name text
  account_name text
  account_number text
  provider_ref text
  is_default boolean
}

Table application {
  id uuid [pk]
  application_number text [unique]
  product_id uuid [ref: > product.id]
  legal_entity_id uuid [ref: > legal_entity.id]
  applicant_party_id uuid [ref: > party.id]
  requested_amount numeric
  requested_currency char(3)
  tenor_months int
  status text
}

Table decision {
  id uuid [pk]
  application_id uuid [ref: > application.id]
  outcome text
  approved_amount numeric
  approved_currency char(3)
  decided_by text
}

Table loan {
  id uuid [pk]
  loan_number text [unique]
  application_id uuid [ref: > application.id]
  product_id uuid [ref: > product.id]
  legal_entity_id uuid [ref: > legal_entity.id]
  borrower_party_id uuid [ref: > party.id]
  currency_code char(3)
  principal_amount numeric
  rc_fee_rate numeric
  interest_rate numeric
  start_date date
  end_date date
  parent_loan_id uuid [ref: > loan.id]
  property_contract_id text
  status text
}

Table amortisation_plan {
  id uuid [pk]
  loan_id uuid [ref: > loan.id]
  version int
  status text
  reason text
  effective_from date
  effective_through date
}

Table amortisation_line {
  id uuid [pk]
  plan_id uuid [ref: > amortisation_plan.id]
  seq_no int
  due_date date
  currency_code char(3)
  amount_principal numeric
  amount_rc_fee numeric
  amount_penalty numeric
  amount_other numeric
}

Table payment {
  id uuid [pk]
  legal_entity_id uuid [ref: > legal_entity.id]
  currency_code char(3)
  amount numeric
  direction text
  provider text
  external_reference text
  payer_party_id uuid [ref: > party.id]
  payee_party_id uuid [ref: > party.id]
  instrument_id uuid [ref: > payment_instrument.id]
  received_at timestamp
  status text
}

Table disbursement {
  id uuid [pk]
  loan_id uuid [ref: > loan.id]
  legal_entity_id uuid [ref: > legal_entity.id]
  instrument_id uuid [ref: > payment_instrument.id]
  currency_code char(3)
  amount numeric
  disbursed_at timestamp
  status text
}

Table payment_allocation {
  id uuid [pk]
  payment_id uuid [ref: > payment.id]
  loan_id uuid [ref: > loan.id]
  plan_id uuid [ref: > amortisation_plan.id]
  line_id uuid [ref: > amortisation_line.id]
  component text
  allocated_amount numeric
}

Table ledger_account {
  id uuid [pk]
  legal_entity_id uuid [ref: > legal_entity.id]
  code text
  name text
  type text
}

Table ledger_entry {
  id uuid [pk]
  legal_entity_id uuid [ref: > legal_entity.id]
  account_id uuid [ref: > ledger_account.id]
  loan_id uuid [ref: > loan.id]
  payment_id uuid [ref: > payment.id]
  disbursement_id uuid [ref: > disbursement.id]
  currency_code char(3)
  amount numeric
  side text
}

Table security_interest {
  id uuid [pk]
  loan_id uuid [ref: > loan.id]
  type text
  party_id uuid [ref: > party.id]
  description text
  value_amount numeric
  value_ccy char(3)
}

Table collections_event {
  id uuid [pk]
  loan_id uuid [ref: > loan.id]
  event_type text
  event_at timestamp
  actor_party_id uuid [ref: > party.id]
  dpd_snapshot int
  amount_involved numeric
  currency_code char(3)
}

Table document {
  id uuid [pk]
  title text
  kind text
  storage_url text
  uploaded_at timestamp
}

Table document_link {
  id uuid [pk]
  document_id uuid [ref: > document.id]
  entity_type text
  entity_id uuid
  role text
}

Table fx_rate {
  id uuid [pk]
  as_of_date date
  from_ccy char(3)
  to_ccy char(3)
  rate numeric
  source text
}
