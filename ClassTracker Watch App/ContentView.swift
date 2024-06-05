import SwiftUI

struct ProgressBar: View {
    // Ez a View tartalmazza a kör alakú progressbar-t
    
    // Az első változó a progress-t írja le egy 0 és 1
    // közti CGFloatként, bár Double eredetileg
    
    // A második változó a színe a körnek, bár ez nincs
    // módosítva jelenleg, lehet az appal összekötni
    // a jövőben ezt majd
    
    // A harmadik változó a kör árnyékának(fényének)
    // vastagságát adja meg 2 és 15 közti értékkel
    
    @Binding var progress: CGFloat
    @Binding var barColor : Color
    @Binding var barRadius : Int
    

    var body: some View {
        RoundedRectangle(cornerRadius: 40)
            .trim(from: 0.0, to: CGFloat(progress))
            .stroke(barColor, lineWidth: 5.0)
            .animation(.easeOut, value: progress)
            .frame(minHeight:0, maxHeight: .infinity, alignment: .top)
            .shadow(color:barColor, radius: CGFloat(barRadius))
            .padding(2.5)
    }
}

// Rövid óra és perc harvester funkció
func hmsOnly(time : Date) -> DateComponents {
    return Calendar.current.dateComponents([.hour, .minute], from: time)
}

// Gyakran használt dateformatter ami átalakít sima stringet egy dátummá
// ami 2001.01.01 napon a megadott órában és percben aktualizált
func dateConvert(timeString : String) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "HH:mm"
    return dateFormatter.date(from: timeString)
}

// Maga az óra object ami tartalmazz a releváns infókat displayhez
// API has to conform to this, or vice versa
struct Lesson : Identifiable{
    var id : UUID = UUID()
    let name : String
    let classroom : String
    let classIcon : String
    let start : String
    let end : String
    
    // Az alábbi kettő funkció átalakítja a stringeket dátummá, ha kell
    func startDate() -> Date? {
        return dateConvert(timeString: start)
    }
    
    func endDate() -> Date? {
        return dateConvert(timeString: end)
    }
}

struct LessonView : View {
    let lesson : Lesson
    
    // Ez adja meg hogy ez egy jelenlegi óra e vagy sem, a színezéshez van felhasználva
    var ongoing : Bool {
        let currentTime = hmsOnly(time:Date())
        if let currentDate = dateConvert(timeString: ("\(currentTime.hour ?? 26):\(currentTime.minute ?? 62)")){
            return isBetween(dis: lesson.startDate(), und: currentDate, dat: lesson.endDate())
        }
        return false
    }
    
    var body: some View {
            HStack{
                Image(systemName:lesson.classIcon).padding(.trailing).foregroundStyle(.blue).frame(alignment: .leading)
                Text(lesson.name)
                Text(lesson.classroom).frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing).foregroundStyle((ongoing) ? .blue : .white)
                    .shadow(color: Color.blue, radius: (ongoing) ? 10 : 0)
            }
    }
}

struct currLesson : View{
    @State private var progress = CGFloat.zero
    @State private var timeLeft : String = "0"
    @State private var barRadius : Int = 5
    @State private var barColor : Color = Color.blue
    @State private var glowDir : Bool = true
    
    @State var lessons : [Lesson]
    
    func hournmin(time: String, minSec : Bool) -> Int?{
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let timeDate = formatter.date(from: time)!
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: timeDate)
        let nowComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        
        var difference : Int
        if(minSec){
            difference = Calendar.current.dateComponents([.second], from: nowComponents, to: timeComponents).second!
            
            return difference
        }
        else{
            difference = Calendar.current.dateComponents([.minute], from: nowComponents, to: timeComponents).minute!
            
            return (0...1).contains(difference/60) ? difference : nil
        }
        
    }
    
    // TODO: Ezt NAGYON kell optimalizálni, undorító, plusz a pulse animation legyen külön dispatch
    func updateProgress() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.065) {
            updateClassInfo()
            
            let placeHolderTime = getlesson().end
            let leftofLesson : Int = hournmin(time: placeHolderTime, minSec: false) ?? -1
            
            switch(leftofLesson){
                case ...0:
                    let leftSecs = (hournmin(time:placeHolderTime, minSec: true) ?? 0)
                    
                    if(leftSecs >= 0){
                        timeLeft = "\(leftSecs) m"
                        
                        if(self.glowDir){
                            barRadius-=1
                            if(barRadius <= 2){
                                glowDir.toggle()
                            }
                        }
                        else if(!self.glowDir){
                            barRadius+=1
                            if(barRadius >= 15){
                                glowDir.toggle()
                            }
                        }
                        
                    self.progress = Double(leftSecs)/60.0
                }
                else{
                    self.progress = 0
                    barRadius = 5
                }
                break
                
                case 1...44:
                    timeLeft = String(leftofLesson+1)
                    self.progress = 1 - (Double(leftofLesson) / 45.0)
                    barRadius = 5
                break
                
                case 45...:
                    timeLeft = ">45"
                    self.progress = 1
                break
                
                default:
                    timeLeft = "-"
                    barRadius = 5
                    break
            }
            
            updateProgress()
        }
    }
    
    func getlesson() -> Lesson{
        
        let currentTime = hmsOnly(time: Date())
        guard let convertedDate = dateConvert(timeString: "\(currentTime.hour!):\(currentTime.minute!)") else {
            return Lesson(name: "Error", classroom: "Error", classIcon: "error", start: "0:00", end: "0:00")
        }
        
        // Átloopol az órákon, ha talál egy current órát akkor returnöli
        for lesson in lessons {
            if isBetween(dis: lesson.startDate(), und: convertedDate, dat: lesson.endDate()) {
                    return lesson
            }
        }
        
        // Az ezelőtti loop failelt, szóval ezzel lecsekkolom hogy két óra
        // közt vagyunk e szendvicselve (metafórikusan)
        for (_, lesson) in lessons.enumerated() {
            if convertedDate < lesson.startDate() ?? Date() {
                return Lesson(name: "Szünet", classroom: lesson.classroom, classIcon: lesson.classIcon, start: lesson.start, end: lesson.end)
            }
        }
        
        // Vagy valami nagyon rosszul sikerült vagy ez ténylegesen az utolsó óra
        return Lesson(name: "Szünet", classroom: "Haza", classIcon: "house", start: lessons.last?.end ?? "0:00", end: "0:00")
        
    }
    
        @State var classIndex: Int = -69
        @State var noClassesLeft: Bool = true
            
            var body: some View {
                VStack {
                    Image(systemName: getlesson().classIcon)
                        .foregroundColor(.blue)
                        .font(.system(size: 40))
                        .padding(.top)
                        .shadow(color: Color.blue, radius: 10)
                    
                    Text(getlesson().name)
                        .padding(.top)
                        .font(.headline)
                    
                    if !noClassesLeft {
                        HStack {
                            Text("\(classIndex + 1).óra")
                                .font(.subheadline)
                            Divider()
                            Text(getlesson().classroom)
                                .font(.subheadline)
                        }
                        .frame(maxHeight: 45)
                    }
                    
                    Text(noClassesLeft ? "Mehetsz haza :D" : "\(timeLeft)p hátra")
                        .padding()
                        .font(.subheadline)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                .background(ProgressBar(progress: $progress, barColor: $barColor, barRadius: $barRadius))
                .onAppear(perform: updateProgress)
                .edgesIgnoringSafeArea(.vertical)
                .onAppear {
                    updateClassInfo()
                }
    }
    
    // Frissíti az infót a jelenlegi óráról mert makacs a swift
    private func updateClassInfo() {
        if let index = lessons.firstIndex(where: { $0.id == getlesson().id }) {
            classIndex = index
            noClassesLeft = false
        } else {
            classIndex = -69
            noClassesLeft = true
        }
    }
}

// Egyszerű, rövid, plusz TF2 referencia, very nice :3
func isBetween(dis: Date?, und: Date, dat: Date?) -> Bool {
    guard let dis = dis, let dat = dat else { return false }
    return dis < und && und < dat
}



struct ContentView: View {
    
    // TODO: rendes adat reading API callal ki kell cserélni rendes adatra, API Insert itt
    
    let classesForToday : [Lesson] = [
        Lesson(name:"Tesi", classroom : "Udvar", classIcon: "figure.badminton", start: "8:00", end: "8:45"),
        Lesson(name:"Irodalom", classroom : "B006", classIcon: "pencil", start: "9:10", end: "9:40"),
        Lesson(name:"Töri", classroom : "D114", classIcon: "book.fill", start: "9:55", end: "10:40"),
        Lesson(name:"Matek", classroom : "A200", classIcon: "plus.forwardslash.minus", start: "10:50", end: "11:35"),
        Lesson(name:"Angol", classroom : "B104", classIcon: "flag.fill", start: "11:45", end: "12:30"),
        Lesson(name:"Földrajz", classroom : "A06", classIcon: "map.fill", start: "12:55", end: "13:40"),
        Lesson(name:"Swift", classroom : "D104", classIcon: "swift", start: "13:50", end: "14:35"),
    ]
    
    
    var body: some View {
        TabView{
            currLesson(lessons: classesForToday)
            VStack{
                List{
                    ForEach(classesForToday){
                        lesson in LessonView(lesson: lesson)
                    }
                }
            }.frame(minWidth:0, maxWidth: .infinity, minHeight:0, maxHeight: .infinity, alignment: .top)
        }.tabViewStyle(.carousel)
        
    }
}

#Preview {
    ContentView()
}
