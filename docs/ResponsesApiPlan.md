# PSAOAI — plan dodania Azure Responses API

Status aktualny: MVP 0.7.0 opublikowane przez użytkownika; [PowerShell Gallery 0.7.0](https://www.powershellgallery.com/packages/PSAOAI/0.7.0) potwierdzone live przez użytkownika/agenta nadrzędnego. S0–S3 offline GREEN i historyczne S4 przez dot-source zachowują swoje granice. Użytkownik później potwierdził natywną akceptację Windows rzeczywiście zainstalowanego źródła z Azure w trybach simple i full: `completed`, `OK`, 16 tokenów łącznie, `store=false`. Nie jest to akceptacja pobranej paczki Gallery ani trwałych ustawień User/Machine.
Baza historycznego planu: lokalny master, commit `50b24fd71696f6d89f65dfe4a50fec2e2d7f4471`; przed zapisem planu working tree czysty. Baza obecnego closeout dokumentacji: `5f475de`, working tree czysty przed edycją.
Zakres obecnego closeout: tylko README, ReleaseNotes i ten plan; bez commit/push/tagów, zmian wersji, manifestu/runtime/source, CI, instalacji, sekretów lub provider calls. Publikacja wykonana wcześniej przez użytkownika, nie przez ten closeout. Historyczne checkpointy poniżej opisują stan w chwili wykonania, nie aktualne zadania.

## Closeout publikacji — ledger

- Potwierdzenie: publiczny link wersji powyżej; dowód dostarczony przez użytkownika/agenta nadrzędnego. Nie pobierano ani nie instalowano paczki Gallery. Polecenie dla użytkownika: `Install-Module -Name PSAOAI -RequiredVersion 0.7.0`.
- Korekty w kolejności: instrukcja exact-version i granice akceptacji w README; stan wydania w ReleaseNotes; aktualny status i następny trigger w tym planie. Historyczne wyniki lokalne pozostają zachowane.
- Artefakty: zapieczętowany stage/ZIP/receipt w scratch pozostaje historyczny i niezmieniony. Aktualny README repo po closeout nie jest deklarowany jako bajtowo identyczny z opublikowaną paczką; nie ma nowego pakowania.
- Akceptacja dokumentacji: PASS — skan aktywnych twierdzeń o publikacji i granic source/paczka; jedyny lokalny link/fragment w trzech plikach poprawny (`#responses-api-070`); dokładny inventory tylko README.md, docs/ReleaseNotes.md, docs/ResponsesApiPlan.md; `git diff --check` exit 0. Link Gallery wskazuje zweryfikowaną przez użytkownika/agenta nadrzędnego wersję 0.7.0; pozostałych zewnętrznych linków nie odpytywano. Nie uruchamiano niezmienionych testów runtime.
- Następny dozwolony kierunek: parkowanie rozwoju; wznowienie dopiero po odtwarzalnym defekcie lub konkretnej potrzebie callera i osobnej zgodzie. Instalacja/akceptacja pobranej paczki Gallery pozostaje oddzielnym, niewykonanym sprawdzeniem, nie automatycznym zadaniem.

## Cel i decyzja

Dodać osobny `Invoke-PSAOAIResponse`, zachowując obecne cmdlety i ich kontrakty. Pierwszy etap: synchroniczny tekstowy POST do Azure Responses v1, pełny obiekt odpowiedzi domyślnie i opcjonalny tekst przez `-SimpleResponse`.

Nie przełączać automatycznie Chat Completions na Responses. Nie obiecywać pełnej obsługi wszystkich funkcji Responses po wdrożeniu podstawowego POST.

## Historyczny stan przed implementacją

- `Private/Get-PSAOAIUrl.ps1` buduje endpointy deployment-scoped, bez Responses.
- `PSAOAI.psd1` ma jawną listę eksportów; nowy cmdlet wymaga dopisania.
- `PSAOAI.psm1` automatycznie ładuje Public/Private, ale import sprawdza PSGallery i inicjalizuje konfigurację. Testy offline muszą izolować te efekty, nie polegać na zwykłym imporcie.
- `Private/Invoke-PSAOAIApiRequest.ps1` wykonuje POST w Start-Job; mock samego Invoke-WebRequest w procesie nadrzędnym nie przetestuje wnętrza joba.
- `Private/Get-Headers.ps1` obsługuje klucz Azure z konfiguracji; nie implementuje Entra ID.
- `.github/workflows/ci.yml` sprawdza import i eksporty, nie kontrakt HTTP. Lokalnie potwierdzono PowerShell 7.6.8 i brak Pester; manifest nie deklaruje minimalnej wersji. Zakres wspieranych runtime’ów wymaga decyzji S0.

## Korekta po krytycznej weryfikacji

Status korekty: wdrożona po późniejszej zgodzie na S1/S2/S3 offline; stare helpery niezmienione.
Potwierdzone podczas przeglądu: lokalny PowerShell 7.6.8, brak dostępnego Pester, brak deklaracji PowerShellVersion w manifeście. Syntetyczna próba Start-Job wykazała dodatkowe metadane joba w wyniku. Istniejący transport dokleja surowe body błędu do wyjątku i emituje pełną odpowiedź w Verbose; nie spełnia nowego kontraktu diagnostyki bez dodatkowej adaptacji.

Decyzja: dedykowany synchroniczny transport `Private/Invoke-PSAOAIResponseRequest.ps1`, bez Start-Job, bez automatycznych retry, bez zmiany starego helpera. Zwraca obiekt zdekodowany z JSON bez metadanych joba. Używa auth api-key zgodnego z istniejącą konfiguracją, lecz nie kopiuje debug headera ani diagnostyki starego transportu. Brak logowania klucza, promptu, odpowiedzi i surowego body błędu, również w Verbose. Diagnostyka ograniczona do statusu HTTP, lokalnego identyfikatora błędu oraz bezpiecznego request ID; nie do dowolnego provider message. Nie przekazywać oryginalnego wyjątku HTTP ani surowego body w ErrorRecord/TargetObject. Nie podążać za przekierowaniami z kluczem.

## Proponowany kontrakt MVP

```powershell
Invoke-PSAOAIResponse -Endpoint 'https://RESOURCE.openai.azure.com' `
  -Deployment 'DEPLOYMENT-NAME' -InputText 'Odpowiedz krótko.' `
  -MaxOutputTokens 512 -SimpleResponse
```

- Endpoint: bazowy adres zasobu HTTPS; budować dokładnie `/openai/v1/responses`, bez `/deployments/...` i bez odziedziczonej datowanej api-version. Akceptować też bazę kończącą się `/openai/v1` bez podwojenia ścieżki; inne ścieżki/query odrzucać z czytelnym błędem.
- `Deployment` mapuje się na `model` w body, nie na segment URL.
- `InputText` wymagany, niepusty tekst; MVP bez pipeline i bez InputItems. Jedno wywołanie oznacza jedno żądanie. Tablice wiadomości, tool outputs i multimodalność odłożone. Unikać nazwy Input kolidującej z automatyczną zmienną PowerShell $input.
- Opcjonalnie: Instructions, MaxOutputTokens, TimeoutSec, SimpleResponse. MaxOutputTokens: dodatnia liczba Int32, pole max_output_tokens; TimeoutSec: dodatnia liczba sekund, domyślnie 60; Instructions: niepusty tekst, pole instructions. ReasoningEffort, Temperature i TopP odłożone do osobnego rozszerzenia po kwalifikacji konkretnego modelu. Body serializować jawnie przez ConvertTo-Json -Depth 20; testować poprawność JSON i UTF-8.
- Dodawać opcjonalne pola tylko gdy jawnie podane; nie wysyłać domyślnie temperature/top_p do modeli, które mogą ich nie wspierać. Walidować wartości według wybranego kontraktu; nie utrzymywać zgadywanej macierzy modeli.
- Jawne store=false, stream=false, background=false w MVP. Brak historii utrwalanej automatycznie przez PSAOAI. Store=false dotyczy zapisu odpowiedzi w Responses; nie jest gwarancją zerowej retencji danych przez usługę.
- Konfiguracja: jawny Endpoint/Deployment ma pierwszeństwo; Endpoint i klucz mogą korzystać z istniejącej konfiguracji. Deployment na początku wymagany jawnie, bez zapisu nowych zmiennych środowiskowych i bez Read-Host.
- Wynik domyślny: pełny obiekt REST, zachowujący id, status, output, usage, error i incomplete_details. Nie mapować go na choices[].
- SimpleResponse: zebrać wszystkie bloki output[].content[] typu output_text w kolejności; nie zakładać output[0], nie wymagać SDK-owego output_text. Odmowy i brak tekstu nie mogą wyglądać jak poprawna pusta odpowiedź.
- Kontrakt statusów: completed — pełny obiekt domyślnie; SimpleResponse łączy bloki output_text bez dodanego separatora. Refusal (także mieszane z tekstem): pełny tryb zachowuje obiekt i ostrzega; SimpleResponse zgłasza PSAOAI.Response.Refused. Incomplete: pełny tryb zachowuje obiekt i ostrzega; SimpleResponse zwraca istniejący tekst z ostrzeżeniem, a bez tekstu zgłasza PSAOAI.Response.NoText. Completed bez tekstu: pełny obiekt zachowany, SimpleResponse — NoText. Failed lub niepuste error: PSAOAI.Response.Failed. Nieoczekiwany/brak statusu, błędny JSON lub niepoprawna struktura: PSAOAI.Response.ProtocolError. HTTP non-2xx: PSAOAI.Response.HttpError; timeout: PSAOAI.Response.Timeout. Błędy terminating, bez surowych danych dostawcy; walidacja wejścia kończy się przed wysłaniem żądania.
- Brak domyślnego logowania payloadu i automatycznych ponowień POST (ryzyko zdublowanych kosztów).

## Kolejność wykonania

### S0 — runtime i runner (DONE offline)

Checkpoint wykonania: baza akceptacji PowerShell 7.6.8 / WSL, bez deklaracji innych wersji/Windows 5.1. SelfTest: passed=2, failed=0. Jednostki dot-source bez importu. Pełny izolowany import rzeczywiście wykonany w tests/Test-ResponsesImport.ps1: tymczasowa kopia modułu zastępuje tylko Set-EnvironmentVariable bezpieczną atrapą, bo dot-source nadpisuje mock z procesu nadrzędnego. Find-Module i Invoke-RestMethod zastąpiono w procesie potomnym; hooki rzeczywiście wywołane po jednym razie, jak również atrapa zapisu konfiguracji. Banner wyłączony przez zmienną Process. Nie kwalifikuje to zwykłego importu jako bezefektowego; bootstrap nadal zmienia stan TLS procesu i ma dotychczasowe efekty poza izolacją.

Pliki: ten plan; nowy test runner dopiero w S1.

- Domyślna propozycja: nowy cmdlet kwalifikowany na PowerShell 7, bez deklarowania wsparcia Windows PowerShell 5.1 i bez zmiany globalnego minimum modułu. S0 wybiera konkretną wspieraną wersję; obecny odczyt 7.6.8 jest obserwacją, nie macierzą zgodności.
- Domyślny runner bez zależności: tests/Test-ResponsesApi.ps1 z asercjami i niezerowym exit code po błędzie; bez instalacji Pester. Pester pozostaje alternatywą wymagającą uzgodnienia instalacji i wersji.
- Ustalić izolację importu: w osobnym procesie testowym zastąpić Find-Module i Set-EnvironmentVariable bezsieciowymi atrapami, wyłączyć banner przez testowy stan procesu, nie zapisywać ustawień User/Machine. Dot-source funkcji dla jednostek, a izolowany pełny import dla eksportu; udokumentować wszystkie atrapy.

Done: zapisana decyzja runtime, wybrana specyfikacja runnera i przepis izolacji; runner powstaje i jest wykonywany w S1. Brak zmian bootstrapu/CI.

### S1 — kontrakt i testy offline (DONE; historyczny RED → GREEN)

Historyczny checkpoint S1 RED: passed=0, failed=28, exit code 1; każda porażka wskazywała brak funkcji produkcyjnej. SelfTest: passed=2, failed=0. Początkowe 28 przypadków obejmowało kontrakt jednostek i atrapę granicy transportu (Url, Headers, BodyJSON, TimeoutSec; wynik zdekodowany REST). Następnie rozszerzono runner o realny loopback HTTP, sanitizację i import; aktualny kompletny zakres i GREEN zapisano w checkpoint S1–S3 poniżej. Atrapy callera nadal nie są dowodem prawdziwego HTTP, dlatego obie warstwy wykonywane są oddzielnie.

Pliki: tests/Test-ResponsesApi.ps1 (nowy), ten plan.

1. Użyć decyzji S0. Polecenie: pwsh -NoLogo -NoProfile -File ./tests/Test-ResponsesApi.ps1. Najpierw kontrolny test runnera, potem RED kontraktu z powodu braku funkcji.
2. Przygotować fixture'y syntetyczne: tekst, wiele output items, reasoning przed tekstem, refusal, incomplete, failed i HTTP error.
3. Zapisać testy URL, body, parameter sets i parsera. Dot-source wyłącznie wymagane funkcje w testach jednostkowych; mock granicy transportu w testach cmdletu.
4. Uruchomić testy i potwierdzić RED z powodu brakującej implementacji, nie błędu środowiska.

Done: jednoznaczny kontrakt testowy, udokumentowany runner i zakres runtime z S0.

### S2 — minimalny cmdlet i transport (DONE offline)

Pliki nowe: `Public/Invoke-PSAOAIResponse.ps1`, `Private/Get-PSAOAIResponseUrl.ps1`, `Private/Get-PSAOAIResponseBody.ps1`, `Private/Get-PSAOAIResponseText.ps1`.
Dodatkowy nowy plik: Private/Invoke-PSAOAIResponseRequest.ps1. Plik istniejący: PSAOAI.psd1; stary transport i auth pozostają niezmienione.

1. Wdrożyć URL/body/parser według testów S1.
2. Wdrożyć dedykowany transport i bezpieczne pobranie istniejącego klucza, bez debug headera, joba i zapisu ustawień; brak konfiguracji zgłasza błąd bez interaktywnego promptu.
3. Dodać eksport do manifestu, zachowując kodowanie istniejącego pliku.
4. Trzy warstwy: cmdlet z atrapą transportu; URL builder z walidacją HTTPS (odrzucanie userinfo, query i fragmentu); rzeczywisty dedykowany transport bezpośrednio na loopback HTTP z syntetycznym kluczem. Serwer testowy uruchamia runner, sprząta w finally. Testować wyłącznie POST, path/body, UTF-8, timeout, 400/401/429/500, redirect bez ponownego wysłania klucza oraz body błędu zawierające syntetyczny sekret/prompt. Nie dodawać publicznej opcji pomijania TLS. Lokalny HTTP nie kwalifikuje TLS ani całej ścieżki produkcyjnego cmdletu — to granica S4.
5. Zrobić izolowany smoke eksportu, bez połączenia z PSGallery i bez trwałych zmian konfiguracji. Sprawdzić brak regresji istniejących eksportów i URL-i.

Done: GREEN offline, poprawny lokalny request transportu i brak regresji eksportów oraz istniejących URL-i. Nie deklarować pełnej regresji starszych cmdletów bez ich odrębnych testów.

### S3 — dokumentacja i gotowość wydania (historyczny DONE offline przed publikacją)

Pliki: `README.md`, `docs/ReleaseNotes.md`, ten plan; wersja w `PSAOAI.psd1` i `PSAOAI.psm1` podniesiona do 0.7.0 po zatwierdzeniu lokalnego przygotowania wydania.

- Dodać quick start, różnicę względem Chat Completions, ograniczenia modeli/regionów, znaczenie store=false, format wyniku i obsługę incomplete/refusal.
- Zapisać rzeczywiste wyniki testów i aktualny następny krok w tym planie po każdej części.
- Propozycja osobnego zatwierdzenia: rozszerzyć CI o nowy eksport i testy offline; obecnego workflow nie zmieniać w ramach samej implementacji bez zgody.
- Kontrole: testy offline, izolowany import, `git diff --check`, dokładny inventory zmian. Commit/push/PSGallery oddzielnie zatwierdzane.

Done: dokumentacja rozróżnia wdrożone MVP, kwalifikację offline i późniejszą akceptację live cmdletu bez bootstrapu; bez publikacji.

### S4 — akceptacja Azure (cmdlet i transport live potwierdzone; bootstrap poza zakresem)

Po osobnej zgodzie użytkownika wykonano jedną próbę gotowego Invoke-PSAOAIResponse na gpt-6.1-sol, z danymi AZURE_API_BASE/AZURE_API_KEY z crewai/.env przekazanymi wyłącznie do środowiska procesu testowego. Dot-source rzeczywistych funkcji Private/Public, bez atrap transportu/auth; pominięto bootstrap modułu ze względu na jego efekty sieciowe/konfiguracyjne. Endpoint pobrano przez prawdziwy lookup konfiguracji procesu. Limit max_output_tokens=512, timeout=90, brak retry. Wynik: exit 0, status completed, model gpt-6.1-sol, tekst OK, input_tokens=11, output_tokens=5, total_tokens=16, reasoning_tokens=0, store=false, incomplete_details=null. Potwierdza rzeczywisty cmdlet, auth, HTTPS transport i parser na wybranym zasobie; nie kwalifikuje zwykłego importu/bootstrappingu live, innych modeli/runtime’ów ani reasoning. Bez trwałej konfiguracji i bez ujawnienia klucza.

Historyczny checkpoint wcześniejszej próby bezpośredniego REST (nie zastępuje późniejszej akceptacji cmdletu powyżej): użytkownik zatwierdził jedną próbę REST z limitem 512 tokenów wyjścia. Dane pobrano lokalnie z /home/voytas/projects/crewai/.env: AZURE_API_BASE, AZURE_API_KEY; model/deployment gpt-6.1-sol. Nie zapisano ani nie wypisano wartości sekretu. Wysłano dokładnie jedno żądanie POST Responses v1, syntetyczny prompt „Reply with exactly: OK”, store/stream/background=false, bez retry i redirect. Rzeczywisty wynik: HTTP 200, status completed, model gpt-6.1-sol, tekst OK, input_tokens=11, output_tokens=5, total_tokens=16, reasoning_tokens=0, incomplete_details=null, store=false. Potwierdza dostępność podstawowego REST na wybranym zasobie; NIE kwalifikuje nieistniejącego jeszcze cmdletu PSAOAI, reasoning ani innych modeli/regionów. Zgoda została wykorzystana na tę jedną próbę; kolejne provider calls wymagają zatwierdzenia.

- Wybrać konkretny zasób, region, deployment, źródło klucza i limit kosztu/tokenów. Nie odczytywać ani wypisywać sekretu w raporcie.
- Jedno krótkie żądanie, weryfikacja endpointu, statusu, tekstu i usage. Osobno sprawdzić model reasoning tylko jeśli ma być objęty deklaracją wsparcia.
- Zapisać zanonimizowany wynik i zakres akceptacji; sukces jednego deploymentu nie dowodzi wsparcia wszystkich modeli/regionów.

Done: działający cmdlet na uzgodnionym Azure deployment, poparty realnym wynikiem.

## Po MVP — osobne rozszerzenia, bez obecnej zgody na wykonanie

1. Stan rozmowy: Store/PreviousResponseId oraz GET/DELETE zapisanej odpowiedzi; jawna retencja i cleanup, bez automatycznego przełączania store na true. Kontynuacja wysyła Instructions świadomie — nie zakłada ich dziedziczenia.
2. Structured Outputs przez text.format, następnie function tools i function_call_output; narzędzia wykonywane przez caller, nigdy automatyczne uruchamianie kodu przez moduł.
3. Streaming SSE: dedykowany parser eventów Responses, nie parser choices[].delta; testy podzielonych ramek, UTF-8, terminalnych statusów i przerwania.
4. Multimodalność, built-in tools, Entra ID i background dopiero według konkretnej potrzeby i kwalifikacji Azure.

## Ryzyka i warunki zatrzymania

- Dostępność endpointu zależy od deploymentu/modelu/regionu; do weryfikacji live.
- Nie przenosić wszystkich parametrów Chat Completions mechanicznie do Responses.
- Import ma efekty sieciowe/konfiguracyjne; ich ogólny refaktor nie jest częścią tego planu.
- Zmiana auth, polityk bezpieczeństwa, szeroki refaktor transportu, instalacje, CI lub provider calls wymagają osobnej zgody, jeśli wychodzą poza zatwierdzony slice.

## Alternatywa i sygnał zmiany decyzji

Alternatywa: rozszerzyć istniejący cmdlet ChatCompletion o tryb Responses. Jest mniej korzystna ze względu na różne schematy wyników, stanu i streamingu. Zmienić rekomendację dopiero gdy caller wymaga jednej powierzchni wywołania i testy potwierdzą bezstratny adapter bez regresji; adapter powinien nadal korzystać z oddzielnego rdzenia Responses.

## Definition of Done MVP

- Osobny eksport, poprawny v1 URL i body model/input, jawne store/stream/background.
- Testy offline oraz lokalny transport przechodzą; zachowane istniejące eksporty i URL-e. Szersze zachowanie starszych cmdletów niekwalifikowane tym zestawem.
- Pełny wynik zachowany, parser nie gubi tekstu ani nie ukrywa odmów/błędów/incomplete.
- Brak sekretnych danych w diagnostyce i brak nowych trwałych ustawień bez zgody.
- Dokumentacja rozróżnia implementację, offline qualification i Azure acceptance.

## Jeden następny slice

Publikacja Gallery 0.7.0 potwierdzona; późniejsza akceptacja Windows dotyczy rzeczywiście zainstalowanego źródła, nie pobranej paczki Gallery. Closeout dokumentacji nie powtarza Azure ani pakowania. Rozwój zaparkowany: następny slice wymaga odtwarzalnego defektu lub konkretnej potrzeby callera oraz osobnej zgody. Proxy, inne modele/regiony/runtime’y i Windows User/Machine persistence nadal niekwalifikowane; commit/push/tagi, CI, instalacje, sekrety i provider calls nie są zatwierdzone.

## Historyczny checkpoint wykonania S1–S3

- Rzeczywisty historyczny RED: `pwsh -NoLogo -NoProfile -File ./tests/Test-ResponsesApi.ps1` → passed=0, failed=28 (brak implementacji).
- Aktualny SelfTest: to samo polecenie z `-SelfTest` → passed=2, failed=0, exit 0.
- Historyczny pełny runner przed closeout: passed=48, failed=0, exit 0. Końcowy runner obejmuje dodatkowo odrzucanie singletonowej tablicy JSON jako root (realny loopback RED 48/1 → GREEN 49/0); serwer potwierdza dokładnie 10 POST, bez redirect-target i retry. Zakres: URL/body/parser/caller, pełne wyniki i nieznane pola, odmowy/incomplete, walidacja przed transportem, HTTP UTF-8, 400/401/429/500, redirect, timeout, invalid-json i invalid-utf8; diagnostyka bez markerów sekretu/promptu, TargetObject i InnerException puste. Proces sprzątany w finally.
- Izolowany import: 8 eksportów (7 istniejących + nowy), 4 stare URL-e z kodowaniem deploymentu; rzeczywiście wykonane hooki PSGallery/REST/zapisu konfiguracji. Nie wykonywano prawdziwego network importu.
- Manifest zachowuje UTF-16 LE BOM; wersje obu plików modułu obecnie 0.7.0 (lokalny release). Stary transport, auth, bootstrap i CI bez zmian. README i ReleaseNotes opisują niewydany zakres offline oraz późniejszą akceptację live dot-sourced cmdletu.
- Transport używa synchronicznego HttpClient bez proxy, automatycznych poświadczeń, redirectów i retry; nie emituje request ID ani payloadów. Środowiska wymagające proxy pozostają niekwalifikowane.
- Ograniczenia: bootstrap modułu niekwalifikowany live; inne runtime’y/modele/regiony, proxy i pełna regresja starych cmdletów niekwalifikowane. TLS/Azure rzeczywistego cmdletu potwierdzone w S4 przez dot-source. Brak nowej autoryzacji na provider calls.

## Historyczny lokalny additive fix Get-PSAOAIEnv (przed publikacją 0.7.0)

- Zatwierdzono i wdrożono wyłącznie inventory: opcjonalny ValidateSet Process/User/Machine; domyślnie wszystkie scope jako osobne obiekty Name/Value/Scope/Info, bez precedence i bez deduplikacji nazw.
- Wszystkie wartości kluczy API maskowane w całości jako `****`, bez dekodowania/założenia szyfrowania. Brak zmiennych: komunikat information stream, zero data rows. Unix może nie mieć inventory User/Machine.
- Rzeczywisty TDD: `pwsh -NoLogo -NoProfile -File ./tests/Test-PSAOAIEnv.ps1` RED passed=0 failed=9 → GREEN passed=9 failed=0. Syntetyczne Process, mock seam User/Machine; bez odczytów realnych sekretów i trwałych zmian. Pełny Responses runner ponownie 49/0, skipped=0, z izolowanym importem.
- Przejrzano, nie zmieniono: Get-EnvironmentVariable stosuje Process→User→Machine i fallback Env; Clear-PSAOAIEnv usuwa stałą listę tylko w User. CI/auth/transport/bootstrap bez zmian; brak provider calls, instalacji, commit/push/tag/publikacji. Wersja nadal lokalna 0.7.0.

## Historyczny bounded import UX fix (przed publikacją 0.7.0)

- Przyczyna: import wywoływał Set-EnvironmentVariable z wynikiem sieciowego Get-APIVersion. Pusty wynik uruchamiał Read-Host; wynik niepusty nadpisywał Process/User. Import teraz tylko odczytuje istniejącą wersję, bez discovery, promptu i zapisu. Brak wersji pozostaje brakiem konfiguracji; interaktywny setup starszych poleceń nie został usunięty.
- Manifest PrivateData.PSData.ReleaseNotes jest jedynym źródłem krótkiej notki bieżącej wersji. Banner/notka wyłączone dla skutecznego PSAOAI_BANNER=0; lookup Process→User→Machine zachowany, wartość 1 włącza notkę. Dokumentacja zachowuje konwencję ustawienia User.
- Aktualny test importu zastępuje wcześniejszą atrapę settera: rzeczywisty kod w kopii modułu, strażniki Read-Host/zapisu/sieci, atrapa PSGallery i wyłącznie syntetyczny odczyt User. RED exit 1: Unexpected interactive prompt during import. GREEN: pięć przypadków, osiem eksportów i cztery stare URL-e w każdym; zero promptów, discovery i zapisów, zachowana konfiguracja, brak historycznych notek.
- Weryfikacja końcowa: Responses 49/0/skipped=0, Env 9/0, SelfTest 2/0; parser PowerShell 42 pliki, Test-ModuleManifest 0.7.0 i FileList 47. Odświeżono allowlist stage/ZIP/inventory/SHA256 w scratch: 47 plików, zgodne bajtowo ze źródłem, bez tests/tools/env/planów. Import niezmodyfikowanej paczki z samą atrapą PSGallery: notka włączona/wyłączona, osiem eksportów, wersja API zachowana. SHA paczki zapisany obok artefaktu, nie duplikowany w planie.
- Historyczne checkpointy S0/S1 zachowują opis ówczesnych atrap; powyższy checkpoint określa aktualną metodę. PSGallery, TLS, auth, proxy, Clear-PSAOAIEnv, CI i inne polecenia bez zmian. Brak nowych provider calls, sekretów, instalacji i publikacji. Zwykły sieciowy import oraz rzeczywiste User persistence na Windows nadal niekwalifikowane.

## Historyczny explicit first-use configuration (ówczesny lokalny niecommitowany slice 0.7.0)

- Zatwierdzony zakres: nowy eksport Initialize-PSAOAIConfiguration, Responses -Interactive jako opt-in, Process-only bez trwałych zapisów User/Machine. Import pozostaje noninteractive; CI, transport, auth lookup, polityki, instalacje, cloud calls, commit/push/publikacja poza zakresem.
- Domyślne Responses podaje konkretnie brakujące nazwy endpoint/key i kieruje do initializera. Mandatory Deployment/InputText nadal obsługuje PowerShell. Initializer pyta o brakujące wartości, waliduje endpoint istniejącym URL helperem przed Read-Host -AsSecureString, zapisuje dopiero po walidacji obu wartości i zwraca status bez sekretu. Klucz w Process env jest plaintext niezbędnym transportowi, nie „zaszyfrowaną konfiguracją”.
- Rzeczywisty RED konfiguracji: passed=2 failed=11 exit 1 (brak initializera/-Interactive i błędów missing-specific). Po korekcie seam wywołania zapisu i ValidateNotNullOrEmpty blokującego przypisanie null podczas lookup: GREEN 13/0. Anulowanie/pusty klucz/niepoprawny endpoint sprawdzają brak transportu i zapisów; syntetyczny Unicode key przechodzi realny lookup -Secure. Testy nie odczytują prawdziwych sekretów ani User/Machine.
- Regresje: Responses 49/0/skipped=0 z realnym loopback, Env 9/0, import pięć przypadków po dziewięć eksportów/cztery URL-e, bez promptów/discovery/zapisów. Native Windows persistence i nowe live acceptance niekwalifikowane.
- Manifest pozostaje 0.7.0 UTF-16LE BOM; FileList rozszerzony o Public/Initialize-PSAOAIConfiguration.ps1. Artefakty i bieżący receipt/hashes odświeżane w scratch, bez tests/env/planów. Commit/push nadal wymaga odrębnej zgody.

## Historical narrow transport-error cascade repair (0.7.0, then-local)

- Preflight: clean master `0997b91`; no CI changes, commits, push, installs, secrets or provider calls. Native Windows checkout not synchronized or modified.
- Diagnosis: transport ThrowTerminatingError terminates its statement, not the enclosing public function under default Continue; null then reaches parser and adds ProtocolError. Global Stop and even an enclosing test try conceal this. Fresh-process Continue probe has no surrounding try; captures redirected records and PowerShell error history when statement termination bypasses pipeline output.
- RED before production changes: Responses 53 passed / 8 failed / 0 skipped; six Continue cases called parser once, two Stop 401 cases lacked safe guidance. With finalized probe and only boundary reverted: 55/6/0. GREEN: 61/0/0, 22 loopback POSTs, no redirects/retries; 401/400/timeout × Continue/Stop × full/simple. One original sanitized HttpError/Timeout, no output, zero parser calls; null TargetObject/InnerException and no secret/prompt markers.
- Minimal repair: nested transport -ErrorAction Stop inside try, public ThrowTerminatingError of its sanitized record. Default caller continues next statement; explicit Stop is catchable. 401 advice is conditional diagnosis: matching resource/key, current key, enabled local API-key authentication; no raw body or certain invalid-key assertion.
- Regression: Env 9/0; Configuration 13/0; isolated Import five cases, nine exports/four legacy URLs. WSL only; no new cloud acceptance or native Windows tests (would require separately approved uncommitted synchronization).
- At that repair checkpoint the allowlisted scratch stage/ZIP/inventory was refreshed against source bytes; version remained 0.7.0 and publication had not yet occurred. This sealed artifact remains historical and is not rebuilt for the later docs-only publication closeout.

## Źródła kontraktu

- https://learn.microsoft.com/en-us/azure/foundry/openai/how-to/responses
- https://learn.microsoft.com/en-us/rest/api/microsoft-foundry/azureopenai/responses

Oficjalne źródła sprawdzone podczas planowania. Dostępność wybranego deploymentu `gpt-6.1-sol` potwierdzono w późniejszym S4; nie jest to macierz modeli/regionów. Końcowy closeout nie wykonuje nowych wywołań Azure.
