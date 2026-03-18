%% ========================================================================
%  PNG vs APNG - 2 Boyutlu Çarpışma Simülasyonu
%
%  Bu simülasyon, Orantılı Seyrüsefer Güdümü (PNG) ile Artırılmış Orantılı
%  Seyrüsefer Güdümü (APNG) arasındaki performans farkını karşılaştırmak
%  amacıyla geliştirilmiştir.
%
%  Temel fark:
%    PNG  — Sadece görüş hattı (LOS) açısal hızını kullanır.
%    APNG — Buna ek olarak hedefin manevra ivmesini de hesaba katar.
%           Bu sayede manevra yapan hedeflere karşı çok daha iyi performans
%           gösterir.
%
%  Senaryo : Füze - Füze, Kafa Kafaya (Head-on)
%            Hedef füze Y ekseninde sabit ivmeyle manevra yapıyor.
%
%  Fiziksel modeller:
%    - Euler sayısal entegrasyonu (adım boyutu: 1 ms)
%    - Birinci derece gecikme: füze güdüm komutuna anında değil,
%      belirli bir zaman sabitiyle (tau) tepki veriyor.
%    - İvme sınırlama: füzenin yapabileceği maksimum manevra sınırlı.
%    - Hız normalizasyonu: her iki füze de sabit hızda uçuyor.
%
%  Kaynak: Zarchan, P., "Tactical and Strategic Missile Guidance",
%          AIAA Progress in Astronautics and Aeronautics.
%
%  Yazar  : [Adınız]
%  Tarih  : 2025
%% ========================================================================
clear; clc; close all;


%% --- GENEL SİMÜLASYON PARAMETRELERİ ---

T    = 0.001;   % Euler adım boyutu [s]
                % Ne kadar küçük olursa simülasyon o kadar hassas olur,
                % ama hesaplama süresi artar. 1 ms iyi bir denge noktasıdır.

tmax = 10;      % Maksimum simülasyon süresi [s]
                % Çarpışma bu süre içinde gerçekleşmezse simülasyon durur.

N    = 4;       % Etkin navigasyon sabiti [-]
                % PNG ve APNG güdüm yasalarındaki kazanç katsayısı.
                % Genellikle 3-5 arasında seçilir. Yüksek değer daha
                % agresif manevra demektir.

g    = 9.81;    % Yerçekimi ivmesi [m/s²]

tau  = 0.2;     % Füze zaman sabiti [s]
                % Birinci derece gecikme modeli için kullanılır.
                % Gerçek bir füze güdüm komutuna anında tepki veremez;
                % aerodinamik ve mekanik gecikmeler bu sabitle modellenir.

aM_limit = 20 * g;  % Füzenin maksimum ivme sınırı [m/s²]
                    % Gerçek füzelerin yapısal ve aerodinamik limitleri
                    % vardır. Bu değerin üzerinde manevra yapılamaz.


%% --- PLATFORM HIZLARİ ---

VM = 900;   % Güdüm füzesinin sabit uçuş hızı [m/s]
            % Simülasyon boyunca bu büyüklük sabit tutulur (hız normalizasyonu).

VT = 600;   % Hedef füzenin sabit uçuş hızı [m/s]


%% --- HEDEF MANEVRA PARAMETRESİ ---

aTmax = 3 * g;  % Hedefin sabit manevra ivmesi [m/s²]
                % Bu değer yörünge ve ivme grafiklerinin çizimi için kullanılır.
                % 3g, 6g, 10g gibi farklı değerlerde test edebilirsiniz.
                % Manevra tarama grafiği (Grafik 3) tüm seviyeleri otomatik
                % olarak analiz eder.


%% --- BAŞLANGIÇ KONUM VE HIZ KOŞULLARI ---

% Güdüm füzesi: sol altta başlıyor, sağa (+X yönünde) ilerliyor.
XM0  = 0;     % Başlangıç X konumu [m]
YM0  = 0;     % Başlangıç Y konumu [m]
VXM0 = VM;    % Başlangıç X hızı: sağa doğru tam hızda [m/s]
VYM0 = 0;     % Başlangıç Y hızı: yok [m/s]

% Hedef füze: sağ üstte başlıyor, sola (-X yönünde) ilerliyor.
% 1000 m yukarıda olması gerçekçi bir kafa kafaya geometrisi sağlıyor.
XT0  = 10000; % Başlangıç X konumu [m]
YT0  = 1000;  % Başlangıç Y konumu [m]
VXT0 = -VT;   % Başlangıç X hızı: sola doğru tam hızda [m/s]
VYT0 = 0;     % Başlangıç Y hızı: manevra simülasyon başladığında devreye girer


%% --- ZAMAN VEKTÖRü VE ADIM SAYISI ---

t      = 0 : T : tmax;
nSteps = length(t);


%% ========================================================================
%  PNG SİMÜLASYONU
%  Güdüm yasası: AM = N * Vc * lambda_dot
%  Sadece LOS açısal hızını kullanır. Hedefin manevrasından habersizdir.
%% ========================================================================

% Başlangıç durumu
XM_png  = XM0;  YM_png  = YM0;
VXM_png = VXM0; VYM_png = VYM0;
XT_png  = XT0;  YT_png  = YT0;
VXT_png = VXT0; VYT_png = VYT0;
aM_png  = 0;    % Füzenin o anki gerçek ivmesi (başlangıçta sıfır)

% Kaydedilecek veriler için boş diziler
store_XM_png  = zeros(1, nSteps);  % Güdüm füzesi X konumu
store_YM_png  = zeros(1, nSteps);  % Güdüm füzesi Y konumu
store_XT_png  = zeros(1, nSteps);  % Hedef X konumu
store_YT_png  = zeros(1, nSteps);  % Hedef Y konumu
store_AM_png  = zeros(1, nSteps);  % Güdüm ivme komutu [m/s²]
store_R_png   = zeros(1, nSteps);  % Füze-hedef mesafesi [m]
store_lam_png = zeros(1, nSteps);  % LOS açısı [rad]
store_t_png   = zeros(1, nSteps);  % Zaman [s]

miss_png     = NaN;
t_impact_png = NaN;
idx_end_png  = nSteps;

for i = 1 : nSteps

    % --- ADIM 1: ANLİK GEOMETRİYİ HESAPLA ---

    dX = XT_png - XM_png;   % Füzeden hedefe X mesafesi
    dY = YT_png - YM_png;   % Füzeden hedefe Y mesafesi
    R  = sqrt(dX^2 + dY^2); % İki platform arasındaki toplam mesafe

    lambda     = atan2(dY, dX);  % LOS açısı: görüş hattının yatay eksenden açısı

    dVX = VXT_png - VXM_png;     % X yönündeki hız farkı
    dVY = VYT_png - VYM_png;     % Y yönündeki hız farkı

    % Kapanma hızı: pozitifse füze hedefe yaklaşıyor, negatifse uzaklaşıyor
    Vc = -(dX*dVX + dVY*dY) / R;

    % LOS açısal hızı: görüş hattı ne kadar hızlı dönüyor
    % Bu değer sıfıra yaklaştığında füze doğrusal çarpışma yolundadır.
    lambda_dot = (dX*dVY - dY*dVX) / R^2;

    % --- ADIM 2: PNG GÜDÜM KOMUTUNU HESAPLA ---

    % PNG güdüm yasası: LOS açısal hızı ve kapanma hızından ivme komutu üret
    AM  = N * Vc * lambda_dot;

    AXT = 0;        % Hedef X ivmesi: yok (sabit hızda X ekseninde ilerliyor)
    AYT = aTmax;    % Hedef Y ivmesi: sabit manevra

    % Birinci derece gecikme modeli:
    % Füze, hesaplanan güdüm komutuna (AM) anında ulaşamaz.
    % Gerçek ivme (aM_png), komuta doğru tau zaman sabitiyle yavaşça yaklaşır.
    aM_png = aM_png + (AM - aM_png) / tau * T;

    % İvme sınırlama: fiziksel limitin üzerine çıkılamaz
    aM_png = max(-aM_limit, min(aM_limit, aM_png));

    % Gerçek ivmeyi X ve Y bileşenlerine dönüştür (LOS koordinat dönüşümü)
    AXM = -aM_png * sin(lambda);
    AYM =  aM_png * cos(lambda);

    % --- ADIM 3: EULER ENTEGRASYONU İLE KONUM VE HIZ GÜNCELLE ---

    % Güdüm füzesi hızını güncelle
    VXM_png = VXM_png + AXM * T;
    VYM_png = VYM_png + AYM * T;

    % Hız büyüklüğünü sabitle: füze sabit hızda (VM) uçar,
    % sadece yön değişir; bu normalizasyon o fiziksel gerçeği yansıtır.
    speed   = sqrt(VXM_png^2 + VYM_png^2);
    VXM_png = VXM_png * (VM / speed);
    VYM_png = VYM_png * (VM / speed);

    % Güdüm füzesi konumunu güncelle
    XM_png = XM_png + VXM_png * T;
    YM_png = YM_png + VYM_png * T;

    % Hedef hızını ve konumunu güncelle
    VXT_png = VXT_png + AXT * T;
    VYT_png = VYT_png + AYT * T;
    XT_png  = XT_png  + VXT_png * T;
    YT_png  = YT_png  + VYT_png * T;

    % --- ADIM 4: VERİYİ KAYDET ---
    store_XM_png(i)  = XM_png;
    store_YM_png(i)  = YM_png;
    store_XT_png(i)  = XT_png;
    store_YT_png(i)  = YT_png;
    store_AM_png(i)  = aM_png;
    store_R_png(i)   = R;
    store_lam_png(i) = lambda;
    store_t_png(i)   = t(i);

    % --- ADIM 5: ÇARPIŞMA KONTROLÜ ---
    % Kapanma hızı negatife döndüğünde füze hedefe en yakın noktayı geçmiştir.
    % Bu an ıskalama mesafesi (miss distance) olarak kaydedilir.
    if Vc < 0
        miss_png     = R;
        t_impact_png = t(i);
        idx_end_png  = i;
        fprintf('--- PNG SONUCU ---\n');
        fprintf('Iskalama Mesafesi : %.4f m\n', miss_png);
        fprintf('Carpışma Ani      : %.4f s\n', t_impact_png);
        break;
    end

end


%% ========================================================================
%  APNG SİMÜLASYONU
%  Güdüm yasası: AM = N * Vc * lambda_dot + (N/2) * (ZEM / tgo^2)
%
%  PNG'den farkı: ZEM (Zero Effort Miss) terimi sayesinde hedefin
%  manevrasını önceden hesaba katar ve daha erken düzeltme yapar.
%
%  ZEM (Sıfır Çaba Iskalama Mesafesi):
%    "Şu andan itibaren hiç manevra yapmazsam, ne kadar ısklarım?"
%    sorusunun cevabıdır. Hedefin gelecekteki konumu tahmin edilerek
%    hesaplanır.
%% ========================================================================

% Başlangıç durumu (PNG ile aynı — adil karşılaştırma için)
XM_apng  = XM0;  YM_apng  = YM0;
VXM_apng = VXM0; VYM_apng = VYM0;
XT_apng  = XT0;  YT_apng  = YT0;
VXT_apng = VXT0; VYT_apng = VYT0;
aM_apng  = 0;

% Kaydedilecek veriler için boş diziler
store_XM_apng  = zeros(1, nSteps);
store_YM_apng  = zeros(1, nSteps);
store_XT_apng  = zeros(1, nSteps);
store_YT_apng  = zeros(1, nSteps);
store_AM_apng  = zeros(1, nSteps);
store_R_apng   = zeros(1, nSteps);
store_lam_apng = zeros(1, nSteps);
store_t_apng   = zeros(1, nSteps);

miss_apng     = NaN;
t_impact_apng = NaN;
idx_end_apng  = nSteps;

for i = 1 : nSteps

    % --- ADIM 1: ANLİK GEOMETRİYİ HESAPLA ---

    dX = XT_apng - XM_apng;
    dY = YT_apng - YM_apng;
    R  = sqrt(dX^2 + dY^2);

    lambda     = atan2(dY, dX);

    dVX = VXT_apng - VXM_apng;
    dVY = VYT_apng - VYM_apng;

    Vc         = -(dX*dVX + dVY*dY) / R;
    lambda_dot = (dX*dVY - dY*dVX) / R^2;

    % --- ADIM 2: APNG GÜDÜM KOMUTUNU HESAPLA ---

    AXT = 0;
    AYT = aTmax;  % Hedefin gerçek manevra ivmesi (feedforward için kullanılır)

    % Kalan uçuş süresi tahmini: mevcut mesafe ve kapanma hızından hesaplanır
    tgo = R / Vc;

    % ZEM hesabı: üç bileşen var
    %   1. Mevcut Y mesafesi (dY)
    %   2. Mevcut Y hız farkının tgo süresince ürettiği mesafe
    %   3. Hedefin manevrasının tgo süresince ürettiği ek Y değişimi
    ZEM = dY + (VYT_apng - VYM_apng) * tgo + 0.5 * AYT * tgo^2;

    % APNG güdüm komutu:
    % PNG terimi + ZEM tabanlı feedforward terimi
    % ZEM büyükse agresif düzelt, tgo küçükse (hedefe yakınken) doğal olarak azalır
    AM = N * Vc * lambda_dot + (N/2) * (ZEM / tgo^2);

    % Birinci derece gecikme modeli
    aM_apng = aM_apng + (AM - aM_apng) / tau * T;

    % İvme sınırlama
    aM_apng = max(-aM_limit, min(aM_limit, aM_apng));

    % Gerçek ivmeyi X ve Y bileşenlerine dönüştür
    AXM = -aM_apng * sin(lambda);
    AYM =  aM_apng * cos(lambda);

    % --- ADIM 3: EULER ENTEGRASYONU İLE KONUM VE HIZ GÜNCELLE ---

    VXM_apng = VXM_apng + AXM * T;
    VYM_apng = VYM_apng + AYM * T;

    speed    = sqrt(VXM_apng^2 + VYM_apng^2);
    VXM_apng = VXM_apng * (VM / speed);
    VYM_apng = VYM_apng * (VM / speed);

    XM_apng  = XM_apng  + VXM_apng * T;
    YM_apng  = YM_apng  + VYM_apng * T;

    VXT_apng = VXT_apng + AXT * T;
    VYT_apng = VYT_apng + AYT * T;
    XT_apng  = XT_apng  + VXT_apng * T;
    YT_apng  = YT_apng  + VYT_apng * T;

    % --- ADIM 4: VERİYİ KAYDET ---
    store_XM_apng(i)  = XM_apng;
    store_YM_apng(i)  = YM_apng;
    store_XT_apng(i)  = XT_apng;
    store_YT_apng(i)  = YT_apng;
    store_AM_apng(i)  = aM_apng;
    store_R_apng(i)   = R;
    store_lam_apng(i) = lambda;
    store_t_apng(i)   = t(i);

    % --- ADIM 5: ÇARPIŞMA KONTROLÜ ---
    if Vc < 0
        miss_apng     = R;
        t_impact_apng = t(i);
        idx_end_apng  = i;
        fprintf('--- APNG SONUCU ---\n');
        fprintf('Iskalama Mesafesi : %.4f m\n', miss_apng);
        fprintf('Carpışma Ani      : %.4f s\n', t_impact_apng);
        break;
    end

end


%% ========================================================================
%  MANEVRA SEVİYESİ TARAMA (1g - 10g, 0.5g adımlarla)
%
%  Her manevra seviyesi için PNG ve APNG simülasyonu ayrı ayrı koşturulur.
%  Sonuçlar Grafik 3'te karşılaştırmalı olarak gösterilir.
%  Bu grafik, APNG'nin yüksek manevralarda PNG'ye kıyasla ne kadar
%  üstün olduğunu net biçimde ortaya koymaktadır.
%% ========================================================================

fprintf('\nManevra seviyesi taraması basliyor (1g - 10g)...\n');

g_levels        = 1 : 0.5 : 10;
nLevels         = length(g_levels);
miss_png_sweep  = zeros(1, nLevels);
miss_apng_sweep = zeros(1, nLevels);

for k = 1 : nLevels

    aTmax_k = g_levels(k) * g;  % Bu adımdaki hedef manevra ivmesi

    % PNG taraması
    XM = XM0; YM = YM0; VXM = VXM0; VYM = VYM0;
    XT = XT0; YT = YT0; VXT = VXT0; VYT = VYT0;
    aM = 0;
    for i = 1 : nSteps
        dX = XT-XM;   dY = YT-YM;
        R  = sqrt(dX^2+dY^2);
        lambda     = atan2(dY,dX);
        dVX = VXT-VXM; dVY = VYT-VYM;
        Vc  = -(dX*dVX+dVY*dY)/R;
        lambda_dot = (dX*dVY-dY*dVX)/R^2;
        AM  = N*Vc*lambda_dot;
        aM  = aM + (AM-aM)/tau*T;
        aM  = max(-aM_limit, min(aM_limit, aM));
        AXM = -aM*sin(lambda);  AYM = aM*cos(lambda);
        VXM = VXM+AXM*T;  VYM = VYM+AYM*T;
        sp  = sqrt(VXM^2+VYM^2);
        VXM = VXM*(VM/sp);  VYM = VYM*(VM/sp);
        XM  = XM+VXM*T;  YM  = YM+VYM*T;
        VYT = VYT+aTmax_k*T;
        XT  = XT+VXT*T;  YT  = YT+VYT*T;
        if Vc < 0
            miss_png_sweep(k) = R;
            break;
        end
    end

    % APNG taraması
    XM = XM0; YM = YM0; VXM = VXM0; VYM = VYM0;
    XT = XT0; YT = YT0; VXT = VXT0; VYT = VYT0;
    aM = 0;
    for i = 1 : nSteps
        dX = XT-XM;   dY = YT-YM;
        R  = sqrt(dX^2+dY^2);
        lambda     = atan2(dY,dX);
        dVX = VXT-VXM; dVY = VYT-VYM;
        Vc  = -(dX*dVX+dVY*dY)/R;
        lambda_dot = (dX*dVY-dY*dVX)/R^2;
        tgo = R/Vc;
        ZEM = dY+(VYT-VYM)*tgo+0.5*aTmax_k*tgo^2;
        AM  = N*Vc*lambda_dot+(N/2)*(ZEM/tgo^2);
        aM  = aM + (AM-aM)/tau*T;
        aM  = max(-aM_limit, min(aM_limit, aM));
        AXM = -aM*sin(lambda);  AYM = aM*cos(lambda);
        VXM = VXM+AXM*T;  VYM = VYM+AYM*T;
        sp  = sqrt(VXM^2+VYM^2);
        VXM = VXM*(VM/sp);  VYM = VYM*(VM/sp);
        XM  = XM+VXM*T;  YM  = YM+VYM*T;
        VYT = VYT+aTmax_k*T;
        XT  = XT+VXT*T;  YT  = YT+VYT*T;
        if Vc < 0
            miss_apng_sweep(k) = R;
            break;
        end
    end

end

fprintf('Tarama tamamlandi.\n\n');


%% ========================================================================
%  GRAFİKLER
%% ========================================================================

t_png  = store_t_png(1:idx_end_png);
t_apng = store_t_apng(1:idx_end_apng);

% Grafik 1 — 2B Uçuş Yörüngesi
figure('Name', 'Yorunge', 'Position', [50 550 800 450]);
plot(store_XM_png(1:idx_end_png)/1000,   store_YM_png(1:idx_end_png),   'b-',  'LineWidth', 2); hold on;
plot(store_XM_apng(1:idx_end_apng)/1000, store_YM_apng(1:idx_end_apng), 'r-',  'LineWidth', 2);
plot(store_XT_png(1:idx_end_png)/1000,   store_YT_png(1:idx_end_png),   'k--', 'LineWidth', 1.5);
plot(XM0/1000, YM0, 'bs', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
plot(XT0/1000, YT0, 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
xlabel('X Konumu [km]');
ylabel('Y Konumu [m]');
title(sprintf('2B Uçuş Yörüngesi — PNG vs APNG  |  Hedef Manevrası: %.0fg', aTmax/g));
legend('PNG Güdüm Füzesi', 'APNG Güdüm Füzesi', 'Hedef Füze', ...
       'Güdüm Füzesi Başlangıcı', 'Hedef Başlangıcı', 'Location', 'best');
grid on;

% Grafik 2 — Güdüm İvme Komutu Geçmişi
figure('Name', 'Ivme', 'Position', [50 50 800 400]);
plot(t_png,  store_AM_png(1:idx_end_png)/g,   'b-', 'LineWidth', 2); hold on;
plot(t_apng, store_AM_apng(1:idx_end_apng)/g, 'r-', 'LineWidth', 2);
yline( aM_limit/g, 'k--', 'LineWidth', 1, 'Label', 'Maks. İvme Limiti');
yline(-aM_limit/g, 'k--', 'LineWidth', 1);
xlabel('Zaman [s]');
ylabel('Güdüm İvme Komutu [g]');
title(sprintf('Güdüm İvme Komutu — PNG vs APNG  |  Hedef Manevrası: %.0fg', aTmax/g));
legend('PNG', 'APNG', 'Location', 'best');
grid on;

% Grafik 3 — Manevra Seviyesi Tarama (ana karşılaştırma grafiği)
figure('Name', 'Tarama', 'Position', [900 50 800 500]);
semilogy(g_levels, miss_png_sweep,  'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b'); hold on;
semilogy(g_levels, miss_apng_sweep, 'r-o', 'LineWidth', 2, 'MarkerFaceColor', 'r');
xlabel('Hedef Manevra Seviyesi [g]');
ylabel('Iskalama Mesafesi [m]  (logaritmik ölçek)');
title('Manevra Seviyesine Göre Iskalama Mesafesi — PNG vs APNG');
legend('PNG', 'APNG', 'Location', 'best');
grid on;
