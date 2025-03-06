import SwiftUI

struct SideMenuView: View {
    @Binding var showSideMenu: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Semi-transparent overlay to dismiss the menu.
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showSideMenu = false
                        }
                    }
                
                // Side panel.
                VStack(alignment: .leading) {
                    Spacer(minLength: 44)  // Leave some top space for safe area.
                    
                    NavigationLink(destination: TestAppView()) {
                        Text("Launch Test App")
                            .font(.headline)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
                .frame(width: geometry.size.width * 0.75, height: geometry.size.height)
                .background(Color(UIColor.systemBackground))
                .shadow(radius: 5)
                .offset(x: showSideMenu ? 0 : -geometry.size.width * 0.75)
                .animation(.easeInOut, value: showSideMenu)
            }
        }
    }
}

struct SideMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuView(showSideMenu: .constant(true))
    }
}
