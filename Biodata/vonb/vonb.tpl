// Von Bertalanffy growth model for estimating Linf and K
DATA_SECTION
  init_int nobs
  init_vector Lmm(1,nobs)
  init_vector age(1,nobs)
  init_int eof
  !! eof==999 ? cout<<"(: --End of data file-- :)\n": cout<<"Error reading data file\n";

  vector L(1,nobs)
  !! L = Lmm / 10.0;

PARAMETER_SECTION
  init_bounded_number K(0.00001,1.0);
  init_bounded_number Linf(1.0,1000.0);
  init_bounded_number tt0(-10.0,1.0,1);
  !! tt0 = 0.0;

  vector Lpred(1,nobs);
  objective_function_value f;
  sdreport_number dummy;

PROCEDURE_SECTION
  Lpred = Linf*(1.0 - exp(-K*(age - tt0)));
  f = (norm2(Lpred-L));

REPORT_SECTION
  report<<"#Linf"<<endl<<Linf<<endl;
  report<<"#K"<<endl<<K<<endl;
  report<<"#tt0"<<endl<<tt0<<endl;
