pNO = load("C:\Users\bmatt\Downloads\unique_pots_no_crosslink.mat")
p45 = load("C:\Users\bmatt\Downloads\unique_pots_45_corsslink.mat")
T45 = load("C:\Users\bmatt\Downloads\mean_thrusts_each_pot_45_crosslink.mat")
TNO = load("C:\Users\bmatt\Downloads\mean_thrusts_each_pot_N)_crosslink.mat")

figure(1)
set(gcf,'DefaultAxesFontSize',16,'DefaultTextFontSize',16) % set default font sizes for figure

% extract vectors (assume fields contain variables; pick first numeric arrays found)
getNumeric = @(s) s.(char(fieldnames(s)));
x1 = getNumeric(pNO); y1 = getNumeric(TNO);
x2 = getNumeric(p45); y2 = getNumeric(T45);

% ensure column vectors
x1 = x1(:); y1 = y1(:);
x2 = x2(:); y2 = y2(:);

% plot data
hold on
h1 = plot(x1,y1,'-bo','DisplayName','No Crosslink','MarkerSize',6,'LineWidth',1.2);
h2 = plot(x2,y2,'-ro','DisplayName','With 45 Crosslink','MarkerSize',6,'LineWidth',1.2);

% linear fits
pfit1 = polyfit(x1,y1,1);
pfit2 = polyfit(x2,y2,1);

% prepare fit lines (use range covering each dataset)
xr1 = linspace(min(x1), max(x1), 100);
yr1 = polyval(pfit1, xr1);
xr2 = linspace(min(x2), max(x2), 100);
yr2 = polyval(pfit2, xr2);

% plot fit lines in same color as original but dashed
c1 = get(h1, 'Color');
c2 = get(h2, 'Color');
hf1 = plot(xr1, yr1, '--', 'Color', c1, 'LineWidth', 1.5, 'DisplayName', sprintf('No Crosslink Fit: T=%.3g x + %.3g', pfit1(1), pfit1(2)));
hf2 = plot(xr2, yr2, '--', 'Color', c2, 'LineWidth', 1.5, 'DisplayName', sprintf('With 45 Crosslink Fit: T=%.3g x + %.3g', pfit2(1), pfit2(2)));

grid on

% build legend including both data and fits
lg = legend([h1 h2 hf1 hf2], {get(h1,'DisplayName'), get(h2,'DisplayName'), get(hf1,'DisplayName'), get(hf2,'DisplayName')}, 'Location','best');
set(lg,'FontSize',16) % ensure legend font size

xlabel('Potentiometer Value')
ylabel('Thrust (units)')
title('Thrust Comparison of Wing with and without a 45 Degree Crosslink')
% ensure axis labels and title use font size 16
set(get(gca,'XLabel'),'FontSize',16)
set(get(gca,'YLabel'),'FontSize',16)

hold off
