obj = @(K) test_mahony_filter_all_in_one(K(1),K(2));
x0 = [0.01;0.2];
[gains, error] = fminunc(obj,x0)